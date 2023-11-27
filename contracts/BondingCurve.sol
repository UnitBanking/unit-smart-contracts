// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './interfaces/IBondingCurve.sol';
import './interfaces/IERC20.sol';
import './interfaces/IInflationOracle.sol';
import './interfaces/IEthUsdOracle.sol';
import { UD60x18, convert, uUNIT, UNIT, unwrap, wrap, exp, ln } from '@prb/math/src/UD60x18.sol';
import './libraries/Math.sol';

/*
 TODOs:
 - reduce OpenZeppelin Math library (we only need min/max funcs ATM)
 - review `IBondingCurve` function visibility
 - clarify initial RR setup
 - verify `burn()` interface
 - update `transfer()` in `burn()` function
 - DISCOUNT - do we need a function (getter/setter)
 */

contract BondingCurve is IBondingCurve {
    /**
     * ================ CONSTANTS ================
     */

    uint256 private constant TWENTY_YEARS_IN_SECONDS = 20 * 365 days;
    UD60x18 private constant TWENTY_YEARS_UD60x18 = UD60x18.wrap(20 * uUNIT);
    UD60x18 private constant ONE_YEAR_IN_SECONDS_UD60x18 = UD60x18.wrap(365 days * uUNIT);
    uint256 public constant SPREAD_PRECISION = 10_000;
    uint256 public constant BASE_SPREAD = 10; // 0.1%
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant HIGH_RR = 4; // (HighRR, TargetRR): normal $UNIT mint/redeem, no auction
    uint256 public constant DISCOUNT = 5_000; // 0.5 or 50%
    uint256 public constant DISCOUNT_PRECISION = 10_000;

    /**
     * ================ STATE VARIABLES ================
     */

    UD60x18 public lastInternalPrice; // IP(t')
    uint256 public lastOracleInflationRate; // r(t') = min(100%, max(0, (ln(Index(t')) – ln(Index(t'- 20years)))/20years))
    uint256 public lastOracleUpdateTimestamp; // t'

    IInflationOracle public inflationOracle;
    IEthUsdOracle public ethUsdOracle;
    address public unitToken;
    address public mineToken;

    /**
     * ================ CONSTRUCTOR ================
     */

    constructor(
        address _unitToken,
        address _mineToken,
        IInflationOracle _inflationOracle,
        IEthUsdOracle _ethUsdOracle
    ) {
        lastInternalPrice = UNIT; // 1

        unitToken = _unitToken;
        mineToken = _mineToken;
        inflationOracle = _inflationOracle;
        ethUsdOracle = _ethUsdOracle;

        updateInternals();
    }

    /**
     * ================ EXTERNAL & PUBLIC FUNCTIONS ================
     */

    receive() external payable {}

    function mint(address receiver) external payable {
        if (receiver == address(0)) revert BondingCurveInvalidReceiver(address(0)); // todo: remove, duplicate in `UnitToken.mint`

        if (_getReserveRatio() < HIGH_RR) revert BondingCurveMintDisabledDueToTooLowRR();

        // P(t) * (1 + spread(t))
        uint256 unitTokenAmount = (msg.value * PRICE_PRECISION) /
            ((getUnitEthPrice() * (SPREAD_PRECISION + getSpread())) / SPREAD_PRECISION);
        IERC20(unitToken).mint(receiver, unitTokenAmount); // TODO: Should the Unit token `mint` function return a bool for backwards compatibility?
    }

    function burn(uint256 unitTokenAmount) external {
        IERC20(unitToken).burn(msg.sender, unitTokenAmount);
        uint256 withdrawEthAmount = ((unitTokenAmount) *
            ((getUnitEthPrice() * (SPREAD_PRECISION - getSpread())) / SPREAD_PRECISION)) / PRICE_PRECISION;
        payable(msg.sender).transfer(withdrawEthAmount);
    }

    function redeem(uint256 mineTokenAmount) external {
        uint256 excessEth = getExcessEthReserve();
        uint256 totalEthAmount = (((excessEth * mineTokenAmount) / IERC20(mineToken).totalSupply()) * (100 - 1)) / 100;

        uint256 userEthAmount = (totalEthAmount * (DISCOUNT_PRECISION - DISCOUNT)) / DISCOUNT_PRECISION;
        uint256 burnEthAmount = totalEthAmount - userEthAmount;

        IERC20(mineToken).burn(msg.sender, mineTokenAmount);
        payable(msg.sender).transfer(userEthAmount);
        payable(address(0)).transfer(burnEthAmount);
    }

    function updateInternals() public {
        uint256 currentOracleUpdateTimestamp = block.timestamp;
        uint256 currentPriceIndex = inflationOracle.getLatestPriceIndex();
        uint256 pastPriceIndex = inflationOracle.getPriceIndexTwentyYearsAgo();

        UD60x18 priceIndexDelta = (ln(convert(currentPriceIndex)).sub(ln(convert(pastPriceIndex)))).div(
            TWENTY_YEARS_UD60x18
        );
        uint256 priceIndexDeltaUint256 = priceIndexDelta.unwrap() / (uUNIT / PRICE_INDEX_PRECISION);

        lastInternalPrice = _getInternalPriceForTimestamp(currentOracleUpdateTimestamp);
        lastOracleInflationRate = Math.min(100 * PRICE_INDEX_PRECISION, Math.max(0, priceIndexDeltaUint256));
        lastOracleUpdateTimestamp = currentOracleUpdateTimestamp;
    }

    // IP(t) = IP(t’) * exp(r(t’) * (t-t’))
    function getInternalPrice() public view returns (uint256) {
        return _getInternalPriceForTimestamp(block.timestamp).unwrap();
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
        excessEth = Math.max(
            0,
            address(this).balance -
                (IERC20(unitToken).totalSupply() * getInternalPrice()) /
                ethUsdOracle.getEthUsdPrice()
        );
    }

    /**
     * ================ INTERNAL FUNCTIONS ================
     */

    function _getInternalPriceForTimestamp(uint256 timestamp) internal view returns (UD60x18) {
        return
            lastInternalPrice *
            exp(
                wrap(lastOracleInflationRate * (uUNIT / PRICE_INDEX_PRECISION)).mul(
                    convert(timestamp - lastOracleUpdateTimestamp).div(ONE_YEAR_IN_SECONDS_UD60x18)
                )
            );
    }

    function _getUnitEthPrice() internal view returns (uint256) {
        uint256 unitTotalSupply = IERC20(unitToken).totalSupply();
        if (unitTotalSupply > 0) {
            return
                Math.min(
                    (unwrap(_getInternalPriceForTimestamp(block.timestamp)) * PRICE_PRECISION) /
                        ethUsdOracle.getEthUsdPrice(),
                    ((address(this).balance - msg.value) * PRICE_PRECISION) / unitTotalSupply
                );
        } else {
            return
                (unwrap(_getInternalPriceForTimestamp(block.timestamp)) * PRICE_PRECISION) /
                ethUsdOracle.getEthUsdPrice();
        }
    }

    function _getReserveRatio() internal view returns (uint256 reserveRatio) {
        uint256 internalPrice = getInternalPrice();
        uint256 unitTokenTotalSupply = IERC20(unitToken).totalSupply();

        if (internalPrice != 0 && unitTokenTotalSupply != 0) {
            reserveRatio =
                (ethUsdOracle.getEthUsdPrice() * (address(this).balance - msg.value)) /
                (internalPrice * unitTokenTotalSupply);
        }
    }
}
