// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './interfaces/IBondingCurve.sol';
import './abstracts/Proxiable.sol';
import './abstracts/ReentrancyGuard.sol';
import './interfaces/IInflationOracle.sol';
import './interfaces/IEthUsdOracle.sol';
import { UD60x18, convert, uUNIT, UNIT, unwrap, wrap, exp, ln } from '@prb/math/src/UD60x18.sol';
import './libraries/Math.sol';
import './libraries/TransferUtils.sol';
import './MineToken.sol';
import './UnitToken.sol';

/*
 TODOs:
 - reduce OpenZeppelin Math library (we only need min/max funcs ATM)
 - review `IBondingCurve` function visibility (possibly convert all to public for improved testability)
 - revisit `burn()` interface upon code integration
 - TBC: make REDEMPTION_DISCOUNT mutable
 - TBC: make oracles mutable
 - add UTs for non reentrant funcs
 */

contract BondingCurve is IBondingCurve, Proxiable, ReentrancyGuard {
    using TransferUtils for address;

    /**
     * ================ CONSTANTS ================
     */

    uint256 private constant TWENTY_YEARS_IN_SECONDS = 20 * 365 days;
    UD60x18 private constant TWENTY_YEARS_UD60x18 = UD60x18.wrap(20 * uUNIT);
    UD60x18 private constant ONE_YEAR_IN_SECONDS_UD60x18 = UD60x18.wrap(365 days * uUNIT);

    uint256 public constant HIGH_RR = 4; // High reserve ratio (RR). (HighRR, TargetRR): normal $UNIT mint/redeem, no auction

    uint256 public constant BASE_SPREAD = 10; // 0.1%
    uint256 public constant SPREAD_PRECISION = 10_000;

    uint256 public constant UNITUSD_PRICE_PRECISION = 1e18; // Must match Unit token precision
    uint256 public constant ETHUSD_PRICE_PRECISION = 1e18; // Must match Unit token precision or UNITUSD_PRICE_PRECISION (which must be the same)

    uint256 public constant REDEMPTION_DISCOUNT = 5_000; // 0.5 or 50%
    uint256 public constant REDEMPTION_DISCOUNT_PRECISION = 10_000;

    uint256 public constant BASE_REDEMPTION_SPREAD = 100; // 0.01 or 1%
    uint256 public constant BASE_REDEMPTION_SPREAD_PRECISION = 10_000;

    address public immutable COLLATERAL_BURN_ADDRESS;

    /**
     * ================ STATE VARIABLES ================
     */

    UD60x18 public lastUnitUsdPrice; // IP(t')
    uint256 public lastOracleInflationRate; // r(t') = min(100%, max(0, (ln(Index(t')) – ln(Index(t'- 20years)))/20years))
    uint256 public lastOracleUpdateTimestamp; // t'

    IERC20 public collateralToken;
    IInflationOracle public inflationOracle;
    IEthUsdOracle public ethUsdOracle;
    UnitToken public unitToken;
    MineToken public mineToken;

    /**
     * ================ CONSTRUCTOR ================
     */

    /**
     * @dev This contract is meant to be used through a proxy. The constructor makes the implementation contract
     * uninitializable, which makes it unusable when called directly.
     */
    constructor(address collateralBurnAddress) {
        initialized = true;
        COLLATERAL_BURN_ADDRESS = collateralBurnAddress;
    }

    /**
     * ================ EXTERNAL & PUBLIC FUNCTIONS ================
     */

    receive() external payable {}

    /**
     * @inheritdoc IBondingCurve
     */
    function initialize(
        IERC20 _collateralToken,
        UnitToken _unitToken,
        MineToken _mineToken,
        IInflationOracle _inflationOracle,
        IEthUsdOracle _ethUsdOracle
    ) external {
        uint256 unitTokenPrecision = 10 ** _unitToken.decimals();
        if (unitTokenPrecision != UNITUSD_PRICE_PRECISION) {
            revert BondingCurveInvalidUnitTokenPrecision(unitTokenPrecision, UNITUSD_PRICE_PRECISION);
        }

        lastUnitUsdPrice = UNIT; // 1

        collateralToken = _collateralToken;
        unitToken = _unitToken;
        mineToken = _mineToken;
        inflationOracle = _inflationOracle;
        ethUsdOracle = _ethUsdOracle;

        updateInternals();

        Proxiable.initialize();
    }

    /**
     * @inheritdoc IBondingCurve
     */
    function mint(address receiver, uint256 collateralAmountIn) external nonReentrant {
        if (_getReserveRatio() < HIGH_RR) {
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
     * @dev Updates internal variables based on data from the inflation oracle. The function is expected to be called once a month.
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

    // IP(t) = IP(t’) * exp(r(t’) * (t-t’))
    function getUnitUsdPrice() public view returns (uint256) {
        return _getUnitUsdPriceForTimestamp(block.timestamp).unwrap();
    }

    // P(t) = min(IP(t)/EP(t), BalanceETH(t)/SupplyUnit(t))
    function getUnitEthPrice() external view returns (uint256) {
        return _getUnitEthPrice(0);
    }

    // RR(t) = (EP(t) * BalanceETH(t)) / (IP(t) * SupplyUnit(t))
    function getReserveRatio() public view returns (uint256) {
        return _getReserveRatio();
    }

    function getSpread() public pure returns (uint256) {
        return BASE_SPREAD + _getDynamicSpread();
    }

    function getExcessCollateralReserve() public view returns (uint256) {
        uint256 unitEthValue = (unitToken.totalSupply() * getUnitUsdPrice()) / ethUsdOracle.getEthUsdPrice();
        uint256 collateralAmount = collateralToken.balanceOf(address(this));

        if (collateralAmount < unitEthValue) {
            return 0;
        } else {
            unchecked {
                // Overflow not possible: collateralAmount >= unitEthValue.
                return collateralAmount - unitEthValue;
            }
        }
    }

    /**
     * ================ HELPER READ-ONLY FUNCTIONS ================
     *
     * The following functions are included to help determine the amount of tokens the end-user will receive in minting,
     * burning, or redeeming scenarios based on the tokens they provide. Given that these amounts depend on market
     * conditions, and more specifically, price feeds from oracles, the results may vary even within the same block.
     * For this reason, they're only to be used for informational purposes (e.g. in frontends) and the end-user should
     * be made aware of potential variations.
     */

    function quoteMint(uint256 collateralAmount) external view returns (uint256) {
        if (_getReserveRatio() < HIGH_RR) {
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
            (collateralAmountIn * UNITUSD_PRICE_PRECISION) /
            ((_getUnitEthPrice(collateralAmountIn) * (SPREAD_PRECISION + getSpread())) / SPREAD_PRECISION);
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
            (collateralAmountIn * UNITUSD_PRICE_PRECISION) /
            ((_getUnitEthPrice(0) * (SPREAD_PRECISION + getSpread())) / SPREAD_PRECISION);
    }

    /**
     * @return Collateral token amount that should be transferred to the user based on the provided `unitTokenAmount` in a burn scenario.
     */
    function _getWithdrawalAmount(uint256 unitTokenAmount) internal view returns (uint256) {
        return
            (unitTokenAmount * (_getUnitEthPrice(0) * (SPREAD_PRECISION - getSpread()))) /
            SPREAD_PRECISION /
            UNITUSD_PRICE_PRECISION;
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
     * @return UNIT price in USD in `UNITUSD_PRICE_PRECISION` precision.
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
     * @return UNIT price in ETH in precision that matches `UNITUSD_PRICE_PRECISION`.
     */
    function _getUnitEthPrice(uint256 transferredCollateralAmount) internal view returns (uint256) {
        uint256 unitTotalSupply = unitToken.totalSupply();
        if (unitTotalSupply > 0) {
            return
                Math.min(
                    (unwrap(_getUnitUsdPriceForTimestamp(block.timestamp)) * ETHUSD_PRICE_PRECISION) /
                        ethUsdOracle.getEthUsdPrice(),
                    ((collateralToken.balanceOf(address(this)) - transferredCollateralAmount) *
                        UNITUSD_PRICE_PRECISION) / unitTotalSupply
                );
        } else {
            return
                (unwrap(_getUnitUsdPriceForTimestamp(block.timestamp)) * ETHUSD_PRICE_PRECISION) /
                ethUsdOracle.getEthUsdPrice();
        }
    }

    function _getReserveRatio() internal view returns (uint256 reserveRatio) {
        uint256 unitUsdPrice = getUnitUsdPrice();
        uint256 unitTokenTotalSupply = unitToken.totalSupply();

        if (unitUsdPrice != 0 && unitTokenTotalSupply != 0) {
            reserveRatio =
                (ethUsdOracle.getEthUsdPrice() * collateralToken.balanceOf(address(this))) / // TODO: can do unchecked subtraction (gas optimization)
                (unitUsdPrice * unitTokenTotalSupply);
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
