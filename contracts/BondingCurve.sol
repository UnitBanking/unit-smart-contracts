// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './interfaces/IBondingCurve.sol';
import './abstracts/Proxiable.sol';
import './interfaces/IInflationOracle.sol';
import './interfaces/IEthUsdOracle.sol';
import { UD60x18, convert, uUNIT, UNIT, unwrap, wrap, exp, ln } from '@prb/math/src/UD60x18.sol';
import './libraries/Math.sol';
import './MineToken.sol';
import './UnitToken.sol';

/*
 TODOs:
 - reduce OpenZeppelin Math library (we only need min/max funcs ATM)
 - review `IBondingCurve` function visibility (possibly convert all to public for improved testability)
 - revisit `burn()` interface upon code integration
 - replace all `transfer()` calls
 - TBC: make REDEMPTION_DISCOUNT mutable
 - TBC: make oracles mutable
 */

contract BondingCurve is IBondingCurve, Proxiable {
    /**
     * ================ CONSTANTS ================
     */

    uint256 private constant TWENTY_YEARS_IN_SECONDS = 20 * 365 days;
    UD60x18 private constant TWENTY_YEARS_UD60x18 = UD60x18.wrap(20 * uUNIT);
    UD60x18 private constant ONE_YEAR_IN_SECONDS_UD60x18 = UD60x18.wrap(365 days * uUNIT);

    uint256 public constant BASE_SPREAD = 10; // 0.1%
    uint256 public constant SPREAD_PRECISION = 10_000;

    uint256 public constant UNITUSD_PRICE_PRECISION = 1e18; // Must match Unit token precision
    uint256 public constant ETHUSD_PRICE_PRECISION = 1e18; // Must match Unit token precision or UNITUSD_PRICE_PRECISION (which must be the same)
    uint256 public constant HIGH_RR = 4; // High reserve ratio (RR). (HighRR, TargetRR): normal $UNIT mint/redeem, no auction

    uint256 public constant REDEMPTION_DISCOUNT = 5_000; // 0.5 or 50%
    uint256 public constant REDEMPTION_DISCOUNT_PRECISION = 10_000;

    /**
     * ================ STATE VARIABLES ================
     */

    UD60x18 public lastUnitUsdPrice; // IP(t')
    uint256 public lastOracleInflationRate; // r(t') = min(100%, max(0, (ln(Index(t')) – ln(Index(t'- 20years)))/20years))
    uint256 public lastOracleUpdateTimestamp; // t'

    IInflationOracle public inflationOracle;
    IEthUsdOracle public ethUsdOracle;
    UnitToken public unitToken;
    MineToken public mineToken;

    /**
     * ================ CONSTRUCTOR ================
     */

    /**
     * @notice This contract uses a Proxy pattern.
     * Locks the contract, to prevent the implementation contract from being used.
     */
    constructor() {
        initialized = true;
    }

    /**
     * ================ EXTERNAL & PUBLIC FUNCTIONS ================
     */

    receive() external payable {}

    /**
     * @inheritdoc IBondingCurve
     */
    function initialize(
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
    function mint(address receiver) external payable {
        if (_getReserveRatio() < HIGH_RR) {
            revert BondingCurveMintDisabledDueToTooLowRR();
        }

        // P(t) * (1 + spread(t))
        uint256 unitTokenAmount = (msg.value * UNITUSD_PRICE_PRECISION) /
            ((getUnitEthPrice() * (SPREAD_PRECISION + getSpread())) / SPREAD_PRECISION);

        unitToken.mint(receiver, unitTokenAmount); // TODO: Should the Unit token `mint` function return a bool for backwards compatibility?
    }

    /**
     * @inheritdoc IBondingCurve
     */
    function burn(uint256 unitTokenAmount) external {
        unitToken.burnFrom(msg.sender, unitTokenAmount);
        uint256 withdrawEthAmount = ((unitTokenAmount) *
            ((getUnitEthPrice() * (SPREAD_PRECISION - getSpread())) / SPREAD_PRECISION)) / UNITUSD_PRICE_PRECISION;

        payable(msg.sender).transfer(withdrawEthAmount);
    }

    /**
     * @inheritdoc IBondingCurve
     */
    function redeem(uint256 mineTokenAmount) external {
        uint256 excessEth = getExcessEthReserve();

        if (excessEth > 0) {
            uint256 totalEthAmount = (excessEth * mineTokenAmount) * (100 - 1) / mineToken.totalSupply() / 100;
            uint256 userEthAmount = (totalEthAmount * (REDEMPTION_DISCOUNT_PRECISION - REDEMPTION_DISCOUNT)) /
                REDEMPTION_DISCOUNT_PRECISION;

            mineToken.burnFrom(msg.sender, mineTokenAmount);
            payable(msg.sender).transfer(userEthAmount);
            payable(address(0)).transfer(totalEthAmount - userEthAmount);
        }
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
    function getUnitEthPrice() public view returns (uint256) {
        return _getUnitEthPrice();
    }

    // RR(t) = (EP(t) * BalanceETH(t)) / (IP(t) * SupplyUnit(t))
    function getReserveRatio() public view returns (uint256) {
        return _getReserveRatio();
    }

    function getSpread() public pure returns (uint256) {
        uint256 dynamicSpread; // TODO: This is TBC

        return BASE_SPREAD + dynamicSpread;
    }

    function getExcessEthReserve() public view returns (uint256 excessEth) {
        uint256 unitEthValue = (unitToken.totalSupply() * getUnitUsdPrice()) / ethUsdOracle.getEthUsdPrice();

        if (address(this).balance < unitEthValue) {
            return 0;
        } else {
            unchecked {
                // Overflow not possible: address(this).balance >= unitEthValue.
                return address(this).balance - unitEthValue;
            }
        }
    }

    /**
     * ================ INTERNAL FUNCTIONS ================
     */

    /**
     * @return UNIT price in USD in `UNITUSD_PRICE_PRECISION` precision.
     */
    function _getUnitUsdPriceForTimestamp(uint256 timestamp) internal view returns (UD60x18) {
        return
            lastUnitUsdPrice *
            exp(
                wrap(lastOracleInflationRate * (uUNIT / PRICE_INDEX_PRECISION)).mul(
                    convert(timestamp - lastOracleUpdateTimestamp).div(ONE_YEAR_IN_SECONDS_UD60x18) // TODO: can do unchecked subtraction (gas optimization)
                )
            );
    }

    /**
     * @return UNIT price in ETH in precision that matches `UNITUSD_PRICE_PRECISION`.
     */
    function _getUnitEthPrice() internal view returns (uint256) {
        uint256 unitTotalSupply = unitToken.totalSupply();
        if (unitTotalSupply > 0) {
            return
                Math.min(
                    (unwrap(_getUnitUsdPriceForTimestamp(block.timestamp)) * ETHUSD_PRICE_PRECISION) /
                        ethUsdOracle.getEthUsdPrice(),
                    ((address(this).balance - msg.value) * UNITUSD_PRICE_PRECISION) / unitTotalSupply
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
                (ethUsdOracle.getEthUsdPrice() * (address(this).balance - msg.value)) / // TODO: can do unchecked subtraction (gas optimization)
                (unitUsdPrice * unitTokenTotalSupply);
        }
    }
}
