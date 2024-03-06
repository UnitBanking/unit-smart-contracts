// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import './interfaces/IBondingCurve.sol';
import './abstracts/Proxiable.sol';
import './abstracts/ReentrancyGuard.sol';
import './abstracts/Ownable.sol';
import './interfaces/IInflationOracle.sol';
import './interfaces/ICollateralUsdOracle.sol';
import { UD60x18, convert, uUNIT, UNIT, unwrap, wrap, exp, ln } from '@prb/math/src/UD60x18.sol';
import './libraries/Math.sol';
import './libraries/TransferUtils.sol';
import './libraries/ProtocolConstants.sol';
import './libraries/PrecisionUtils.sol';
import './interfaces/IMineToken.sol';
import './interfaces/IUnitToken.sol';

/*
 TODOs:
 - add event logging
 - remove ReentrancyGuard, for now the collateral token can be trusted
 - reduce OpenZeppelin Math library (we only need min/max funcs ATM)
 - review `IBondingCurve` function visibility (possibly convert all to public for improved testability)
 - revisit `burn()` interface upon code integration
 - TBC: make REDEMPTION_DISCOUNT mutable
 - TBC: make oracles mutable
 - add UTs for non reentrant funcs
 */

/**
 * @dev IMPORTANT: This contract implements a proxy pattern. Do not modify inheritance list in this contract.
 * Adding, removing, changing or rearranging these base contracts can result in a storage collision after a contract upgrade.
 */
contract BondingCurve is IBondingCurve, Proxiable, ReentrancyGuard, Ownable {
    using TransferUtils for address;
    using PrecisionUtils for uint256;

    /**
     * ================ CONSTANTS ================
     */

    uint256 private constant TWENTY_YEARS_IN_SECONDS = 20 * 365 days;
    UD60x18 private constant TWENTY_YEARS_UD60x18 = UD60x18.wrap(20 * uUNIT);
    UD60x18 private constant ONE_YEAR_IN_SECONDS_UD60x18 = UD60x18.wrap(365 days * uUNIT);

    uint256 public constant BASE_SPREAD = 10; // 0.001 or 0.1%
    uint256 public constant SPREAD_PRECISION = 10_000;

    uint256 public constant REDEMPTION_DISCOUNT = 5_000; // 0.5 or 50%
    uint256 public constant REDEMPTION_DISCOUNT_PRECISION = 10_000;

    uint256 public constant BASE_REDEMPTION_SPREAD = 100; // 0.01 or 1%
    uint256 public constant BASE_REDEMPTION_SPREAD_PRECISION = 10_000;

    uint256 public immutable STANDARD_PRECISION;
    address public immutable COLLATERAL_BURN_ADDRESS;

    IERC20 public immutable collateralToken;
    uint256 private immutable collateralTokenDecimals;

    IUnitToken public immutable unitToken;
    IMineToken public immutable mineToken;

    IInflationOracle public immutable inflationOracle;
    ICollateralUsdOracle public immutable collateralUsdOracle;

    /**
     * ================ STATE VARIABLES ================
     */

    /**
     * IMPORTANT:
     * !STORAGE COLLISION WARNING!
     * Adding, removing or rearranging undermentioned state variables can result in a storage collision after a contract
     * upgrade. Any new state variables must be added beneath these to prevent storage conflicts.
     */

    UD60x18 public lastUnitUsdPrice; // IP(t')
    uint256 public lastOracleInflationRate; // r(t') = min(100%, max(0, (ln(Index(t')) – ln(Index(t'- 20years)))/20years))
    uint256 public lastOracleUpdateTimestamp; // t'

    address public unitAuction;

    /**
     * IMPORTANT:
     * !STORAGE COLLISION WARNING!
     * Adding, removing or rearranging above state variables can result in a storage collision after a contract upgrade.
     * Any new state variables must be added beneath these to prevent storage conflicts.
     */

    /**
     * ================ CONSTRUCTOR ================
     */

    /**
     * @dev This contract is meant to be used through a proxy. The constructor makes the implementation contract
     * uninitializable, which makes it unusable when called directly.
     */
    constructor(
        IERC20 _collateralToken,
        address collateralBurnAddress,
        IUnitToken _unitToken,
        IMineToken _mineToken,
        IInflationOracle _inflationOracle,
        ICollateralUsdOracle _collateralUsdOracle
    ) {
        STANDARD_PRECISION = ProtocolConstants.STANDARD_PRECISION;
        COLLATERAL_BURN_ADDRESS = collateralBurnAddress;

        collateralToken = _collateralToken;
        collateralTokenDecimals = _collateralToken.decimals();
        unitToken = _unitToken;
        mineToken = _mineToken;
        inflationOracle = _inflationOracle;
        collateralUsdOracle = _collateralUsdOracle;

        // Enforce precision requirements
        uint256 unitTokenPrecision = 10 ** _unitToken.decimals();
        if (unitTokenPrecision != STANDARD_PRECISION) {
            revert BondingCurveInvalidUnitTokenPrecision(unitTokenPrecision, STANDARD_PRECISION);
        }

        uint256 collateralUsdPricePrecision = _collateralUsdOracle.getCollateralUsdPricePrecision();
        if (collateralUsdPricePrecision != STANDARD_PRECISION) {
            revert BondingCurveInvalidCollateralPricePrecision(collateralUsdPricePrecision, STANDARD_PRECISION);
        }

        super.initialize();
    }

    /**
     * ================ EXTERNAL & PUBLIC FUNCTIONS ================
     */

    function initialize() public override {
        _setOwner(msg.sender);

        lastUnitUsdPrice = UNIT; // 1

        updateInternals();

        super.initialize();
    }

    function setUnitAuction(address _unitAuction) external onlyOwner {
        unitAuction = _unitAuction;
    }

    /**
     * @inheritdoc IBondingCurve
     */
    function transferCollateralToken(address receiver, uint256 amount) external {
        if (msg.sender != unitAuction) {
            revert BondingCurveForbidden();
        }

        TransferUtils.safeTransfer(collateralToken, receiver, amount);
    }

    /**
     * @inheritdoc IBondingCurve
     */
    function mint(address receiver, uint256 collateralAmountIn) external nonReentrant {
        if (getReserveRatio() < ProtocolConstants.HIGH_RR) {
            revert BondingCurveReserveRatioTooLow();
        }

        uint256 transferredCollateralAmount = TransferUtils.safeTransferFrom(
            collateralToken,
            msg.sender,
            address(this),
            collateralAmountIn
        );

        unitToken.mint(receiver, _getMintAmount(transferredCollateralAmount)); // TODO: Should the Unit token `mint` function return a bool for backwards compatibility?
    }

    /**
     * @inheritdoc IBondingCurve
     */
    function burn(uint256 unitTokenAmount) external nonReentrant {
        TransferUtils.safeTransfer(collateralToken, msg.sender, _getWithdrawalAmount(unitTokenAmount));

        unitToken.burnFrom(msg.sender, unitTokenAmount);
    }

    /**
     * @inheritdoc IBondingCurve
     */
    function redeem(uint256 mineTokenAmount) external nonReentrant {
        uint256 excessCollateralAmount = getExcessCollateralReserve();
        (uint256 userCollateralAmount, uint256 burnCollateralAmount) = _getRedemptionAmounts(
            mineTokenAmount,
            excessCollateralAmount
        );

        mineToken.burnFrom(msg.sender, excessCollateralAmount == 0 ? 0 : mineTokenAmount);
        TransferUtils.safeTransfer(collateralToken, msg.sender, userCollateralAmount);
        TransferUtils.safeTransfer(collateralToken, COLLATERAL_BURN_ADDRESS, burnCollateralAmount);
    }

    /**
     * @inheritdoc IBondingCurve
     */
    function updateInternals() public {
        uint256 currentOracleUpdateTimestamp = block.timestamp;
        uint256 currentPriceIndex = inflationOracle.getLatestPriceIndex();
        uint256 pastPriceIndex = inflationOracle.getPriceIndexTwentyYearsAgo();

        lastUnitUsdPrice = _getUnitUsdPriceForTimestamp(currentOracleUpdateTimestamp);
        lastOracleUpdateTimestamp = currentOracleUpdateTimestamp;

        if (currentPriceIndex <= pastPriceIndex) {
            lastOracleInflationRate = 0;
        } else {
            UD60x18 priceIndexDelta = (ln(convert(currentPriceIndex)).sub(ln(convert(pastPriceIndex)))).div(
                TWENTY_YEARS_UD60x18
            );
            uint256 priceIndexDeltaUint256 = priceIndexDelta.unwrap() / (uUNIT / PRICE_INDEX_PRECISION);

            lastOracleInflationRate = Math.min(100 * PRICE_INDEX_PRECISION, priceIndexDeltaUint256);
        }
    }

    function getUnitUsdPrice() public view returns (uint256) {
        return _getUnitUsdPriceForTimestamp(block.timestamp).unwrap();
    }

    function getUnitCollateralPrice() external view returns (uint256) {
        return _getUnitCollateralPrice(0);
    }

    function getReserveRatio() public view returns (uint256 reserveRatio) {
        uint256 unitUsdPrice = getUnitUsdPrice();
        uint256 unitTokenTotalSupply = unitToken.totalSupply();

        if (unitUsdPrice != 0 && unitTokenTotalSupply != 0) {
            reserveRatio =
                ((collateralUsdOracle.getCollateralUsdPrice() * collateralToken.balanceOf(address(this))) *
                    STANDARD_PRECISION) /
                (unitUsdPrice * unitTokenTotalSupply);
        }
    }

    function getSpread() public pure returns (uint256) {
        return BASE_SPREAD + _getDynamicSpread();
    }

    /**
     * @inheritdoc IBondingCurve
     */
    function getExcessCollateralReserve() public view returns (uint256) {
        uint256 unitCollateralValue = (unitToken.totalSupply() * getUnitUsdPrice()).fromStandardPrecision(
            collateralTokenDecimals
        ) / collateralUsdOracle.getCollateralUsdPrice();
        uint256 collateralAmount = collateralToken.balanceOf(address(this));

        if (collateralAmount < unitCollateralValue) {
            return 0;
        } else {
            unchecked {
                // Overflow not possible: collateralAmount >= unitCollateralValue.
                return collateralAmount - unitCollateralValue;
            }
        }
    }

    /**
     * @inheritdoc IBondingCurve
     */
    function getMintPrice() external view returns (uint256) {
        return (_getUnitCollateralPrice(0) * (SPREAD_PRECISION + getSpread())) / SPREAD_PRECISION;
    }

    /**
     * @inheritdoc IBondingCurve
     */
    function getBurnPrice() external view returns (uint256) {
        return (_getUnitCollateralPrice(0) * (SPREAD_PRECISION - getSpread())) / SPREAD_PRECISION;
    }

    /**
     * ================ HELPER READ-ONLY FUNCTIONS ================
     *
     * The following functions are included to help determine the amount of tokens the end-user will receive in minting,
     * burning, redeeming, or in auction scenarios, based on the tokens they provide. Given that these amounts depend
     * on market conditions, and more specifically, price feeds from oracles, the results may vary even within the same
     * block. For this reason, they are meant to be used only for informational purposes (e.g. in frontends)
     * and the end-user should be made aware of potential result variations between one of these functions is called
     * and the trade call.
     */

    function quoteMint(uint256 collateralAmount) external view returns (uint256) {
        if (getReserveRatio() < ProtocolConstants.HIGH_RR) {
            revert BondingCurveReserveRatioTooLow();
        }

        return _getQuoteMintAmount(collateralAmount);
    }

    function quoteBurn(uint256 unitTokenAmount) external view returns (uint256) {
        return _getWithdrawalAmount(unitTokenAmount);
    }

    function quoteRedeem(uint256 mineTokenAmount) external view returns (uint256, uint256) {
        return _getRedemptionAmounts(mineTokenAmount, getExcessCollateralReserve());
    }

    /**
     * @inheritdoc IBondingCurve
     */
    function quoteUnitBurnAmountForHighRR(uint256 unitCollateralPrice) external view returns (uint256 unitAmount) {
        uint256 desiredRR = ProtocolConstants.HIGH_RR - 1;
        uint256 unitUsdPrice = getUnitUsdPrice();
        uint256 collateralUsdPrice = collateralUsdOracle.getCollateralUsdPrice();

        unitAmount =
            ((unitToken.totalSupply() * unitUsdPrice * desiredRR) -
                (collateralUsdPrice * collateralToken.balanceOf(address(this)) * STANDARD_PRECISION)
                    .toStandardPrecision(collateralTokenDecimals)) /
            ((desiredRR * unitUsdPrice) - (collateralUsdPrice * unitCollateralPrice));
    }

    /**
     * @inheritdoc IBondingCurve
     */
    function quoteCollateralAmountInForTargetRR(
        uint256 unitCollateralPrice
    ) external view returns (uint256 collateralAmount) {
        uint256 desiredRR = ProtocolConstants.TARGET_RR;
        uint256 unitUsdPrice = getUnitUsdPrice();
        uint256 collateralUsdPrice = collateralUsdOracle.getCollateralUsdPrice();

        collateralAmount =
            ((collateralUsdPrice *
                unitCollateralPrice *
                collateralToken.balanceOf(address(this)).toStandardPrecision(collateralTokenDecimals) *
                STANDARD_PRECISION) - (desiredRR * unitUsdPrice * unitToken.totalSupply() * unitCollateralPrice)) /
            (((desiredRR * unitUsdPrice) - (collateralUsdPrice * unitCollateralPrice)) * STANDARD_PRECISION);

        collateralAmount = collateralAmount.fromStandardPrecision(collateralTokenDecimals);
    }

    /**
     * ================ INTERNAL FUNCTIONS ================
     */

    /**
     * @notice Calculates the amount of UNIT token that should be minted for the collateral amount that has already been
     * transferred for minting.
     * @param collateralAmountIn Collateral token amount transferred.
     * @return UNIT token amount that should be minted for `collateralAmountIn`.
     */
    function _getMintAmount(uint256 collateralAmountIn) internal view returns (uint256) {
        return
            (collateralAmountIn * STANDARD_PRECISION) /
            ((_getUnitCollateralPrice(collateralAmountIn) * (SPREAD_PRECISION + getSpread())) / SPREAD_PRECISION);
    }

    /**
     * @notice Calculates the amount of UNIT token that would be minted for the provided collateral amount in a mint scenario.
     * @dev This function must be used only in a quote scenario, when no collateral tokens have been transferred in the call.
     * @param collateralAmountIn Collateral token amount that can potentially be provided and should be used for quoting
     * UNIT token amount.
     * @return UNIT token amount that would be minted for `collateralAmountIn`.
     */
    function _getQuoteMintAmount(uint256 collateralAmountIn) internal view returns (uint256) {
        return
            (collateralAmountIn * STANDARD_PRECISION) /
            ((_getUnitCollateralPrice(0) * (SPREAD_PRECISION + getSpread())) / SPREAD_PRECISION);
    }

    /**
     * @return Collateral token amount that should be transferred to the user based on the provided `unitTokenAmount` in a burn scenario.
     */
    function _getWithdrawalAmount(uint256 unitTokenAmount) internal view returns (uint256) {
        return
            (unitTokenAmount * (_getUnitCollateralPrice(0) * (SPREAD_PRECISION - getSpread()))) /
            SPREAD_PRECISION /
            STANDARD_PRECISION;
    }

    /**
     * @dev Called to calculate the collateral token amounts when redeeming the collateral with MINE token.
     * @return userCollateralAmount Collateral token amount that should be transferred to the user based on the provided `mineTokenAmount`.
     * @return burnCollateralAmount Collateral token amount that should be burned based on the provided `mineTokenAmount`.
     */
    function _getRedemptionAmounts(
        uint256 mineTokenAmount,
        uint256 excessCollateral
    ) internal view returns (uint256 userCollateralAmount, uint256 burnCollateralAmount) {
        uint256 totalCollateralAmount = ((excessCollateral * mineTokenAmount) *
            (BASE_REDEMPTION_SPREAD_PRECISION - _getBaseRedemptionSpread())) /
            mineToken.totalSupply() /
            BASE_REDEMPTION_SPREAD_PRECISION;
        userCollateralAmount =
            (totalCollateralAmount * (REDEMPTION_DISCOUNT_PRECISION - _getRedemptionDiscount())) /
            REDEMPTION_DISCOUNT_PRECISION;
        burnCollateralAmount = totalCollateralAmount - userCollateralAmount;
    }

    /**
     * @return UNIT price in USD in `STANDARD_PRECISION`.
     */
    function _getUnitUsdPriceForTimestamp(uint256 timestamp) internal view returns (UD60x18) {
        uint256 timestampDelta;
        unchecked {
            timestampDelta = timestamp - lastOracleUpdateTimestamp;
        }

        return
            lastUnitUsdPrice *
            exp(
                wrap(lastOracleInflationRate * (uUNIT / PRICE_INDEX_PRECISION)).mul(convert(timestampDelta)).div(
                    ONE_YEAR_IN_SECONDS_UD60x18
                )
            );
    }

    /**
     * @param transferredCollateralAmount Collateral token amount that was transferred in the current call context
     * and should not be included in price calculation.
     * @return UNIT price in collateral token in `STANDARD_PRECISION`.
     */
    function _getUnitCollateralPrice(uint256 transferredCollateralAmount) internal view returns (uint256) {
        uint256 unitTotalSupply = unitToken.totalSupply();
        if (unitTotalSupply > 0) {
            return
                Math.min(
                    (unwrap(_getUnitUsdPriceForTimestamp(block.timestamp)) * STANDARD_PRECISION) /
                        collateralUsdOracle.getCollateralUsdPrice(),
                    (
                        ((collateralToken.balanceOf(address(this)) - transferredCollateralAmount) * STANDARD_PRECISION)
                            .toStandardPrecision(collateralTokenDecimals)
                    ) / unitTotalSupply
                );
        } else {
            return
                (unwrap(_getUnitUsdPriceForTimestamp(block.timestamp)) * STANDARD_PRECISION) /
                collateralUsdOracle.getCollateralUsdPrice();
        }
    }

    function _getRedemptionDiscount() internal pure returns (uint256) {
        return REDEMPTION_DISCOUNT;
    }

    function _getBaseRedemptionSpread() internal pure returns (uint256) {
        return BASE_REDEMPTION_SPREAD;
    }

    /**
     * @dev This function is TBD.
     */
    function _getDynamicSpread() internal pure returns (uint256) {
        return 0;
    }
}
