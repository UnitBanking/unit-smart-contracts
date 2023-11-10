// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import './Errors.sol';
import './interfaces/IBondingCurve.sol';
import './interfaces/IERC20.sol';
import './interfaces/IInflationOracle.sol';
import './interfaces/IEthUsdOracle.sol';
import { UD60x18, convert, uUNIT, UNIT, unwrap, wrap, exp, ln } from '@prb/math/src/UD60x18.sol';
import './libraries/Math.sol';

import "forge-std/console.sol";

/*
 TODOs:
 - reduce OpenZeppelin Math library (we only need min/max funcs ATM)
 - review `IBondingCurve` function visibility
 */

// setup initial RR - 5 wei ETH and 1 wei UNIT
// new branch and PR

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

    // Reserve ratio
    uint256 public constant HIGH_RR = 4; // (HighRR, TargetRR): normal $UNIT mint/redeem, no auction

    /**
     * ================ STATE VARIABLES ================
     */

    UD60x18 public lastInternalPrice; // IP(t')
    uint256 public lastOracleInflationRate; // r(t') = min(100%, max(0, (ln(Index(t')) – ln(Index(t'- 20years)))/20years))
    uint256 public lastOracleUpdateTimestamp; // t'

    IInflationOracle public inflationOracle;
    IEthUsdOracle public ethUsdOracle;
    IERC20 public unitToken;

    /**
     * ================ CONSTRUCTOR ================
     */

    constructor(IERC20 _unitToken, IInflationOracle _inflationOracle, IEthUsdOracle _ethUsdOracle) {
        lastInternalPrice = UNIT; // 1

        unitToken = _unitToken;
        inflationOracle = _inflationOracle;
        ethUsdOracle = _ethUsdOracle;

        updateInternals();
    }

    /**
     * ================ EXTERNAL & PUBLIC FUNCTIONS ================
     */

    receive() external payable {}

    function mint(address receiver) external payable {
        if (receiver == address(0)) revert InvalidReceiver(); // todo: remove, duplicate in `UnitToken.mint`
        uint256 reserveRatio = getReserveRatio();
        if (reserveRatio < HIGH_RR) revert MintDisabledDueToTooLowRR();
        // P(t) * (1 + spread(t))
        uint256 unitTokenAmount = (msg.value * PRICE_PRECISION) /
            ((getUnitEthPrice() * (SPREAD_PRECISION + getSpread())) / SPREAD_PRECISION);
        unitToken.mint(receiver, unitTokenAmount); // TODO: Should the Unit token `mint` function return a bool for backwards compatibility?
    }

    function burn() external {}

    // IP(t) = IP(t’) * exp(r(t’) * (t-t’))
    function getInternalPrice() public view returns (uint256) {
        return getInternalPriceForTimestamp(block.timestamp).unwrap();
    }

    function updateInternals() public {
        uint256 currentOracleUpdateTimestamp = block.timestamp;
        uint256 currentPriceIndex = inflationOracle.getLatestPriceIndex();
        uint256 pastPriceIndex = inflationOracle.getPriceIndexTwentyYearsAgo();

        UD60x18 priceIndexDelta = (ln(convert(currentPriceIndex)).sub(ln(convert(pastPriceIndex)))).div(
            TWENTY_YEARS_UD60x18
        );
        uint256 priceIndexDeltaUint256 = priceIndexDelta.unwrap() / (uUNIT / PRICE_INDEX_PRECISION);

        lastInternalPrice = getInternalPriceForTimestamp(currentOracleUpdateTimestamp);
        lastOracleInflationRate = Math.min(100 * PRICE_INDEX_PRECISION, Math.max(0, priceIndexDeltaUint256));
        lastOracleUpdateTimestamp = currentOracleUpdateTimestamp;
    }

    // P(t) = min(IP(t)/EP(t), BalanceETH(t)/SupplyUnit(t))
    function getUnitEthPrice() public view returns (uint256) {
        uint256 unitTotalSupply = unitToken.totalSupply();
        if (unitTotalSupply > 0) {
            return
                Math.min(
                    unwrap(getInternalPriceForTimestamp(block.timestamp)) * PRICE_PRECISION / ethUsdOracle.getEthUsdPrice(),
                    address(this).balance * PRICE_PRECISION / unitToken.totalSupply()
                );
        } else {
            return unwrap(getInternalPriceForTimestamp(block.timestamp)) * PRICE_PRECISION / ethUsdOracle.getEthUsdPrice();
        }
    }

    // RR(t) = (EP(t) * BalanceETH(t)) / (IP(t) * SupplyUnit(t))
    function getReserveRatio() public view returns (uint256 reserveRatio) {
        uint256 internalPrice = getInternalPrice();
        uint256 unitTokenTotalSupply = unitToken.totalSupply();
        if (internalPrice == 0 || unitTokenTotalSupply == 0) {
            reserveRatio = 0;
        } else {
            reserveRatio =
                (ethUsdOracle.getEthUsdPrice() * address(this).balance) /
                (internalPrice * unitTokenTotalSupply);
        }
    }

    function getSpread() public pure returns (uint256) {
        uint256 dynamicSpread; // TODO: This is TBC

        return BASE_SPREAD + dynamicSpread;
    }

    /**
     * ================ INTERNAL FUNCTIONS ================
     */

    function getInternalPriceForTimestamp(uint256 timestamp) internal view returns (UD60x18) {
        return
            lastInternalPrice *
            exp(
                wrap(lastOracleInflationRate * (uUNIT / PRICE_INDEX_PRECISION)).mul(
                    convert(timestamp - lastOracleUpdateTimestamp).div(ONE_YEAR_IN_SECONDS_UD60x18)
                )
            );
    }
}
