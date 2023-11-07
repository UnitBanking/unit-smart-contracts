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
 */

contract BondingCurve is IBondingCurve {
    /**
     * ================ CONSTANTS ================
     */

    uint256 private constant TWENTY_YEARS_IN_SECONDS = 20 * 365 days;
    UD60x18 private constant TWENTY_YEARS_UD60x18 = UD60x18.wrap(20 * uUNIT);
    UD60x18 private constant ONE_YEAR_IN_SECONDS_UD60x18 = UD60x18.wrap(365 days * uUNIT);
    uint256 public constant BASE_SPREAD = 1;

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
        lastInternalPrice = UNIT;

        unitToken = _unitToken;
        inflationOracle = _inflationOracle;
        ethUsdOracle = _ethUsdOracle;

        updateInternals();
    }

    /**
     * ================ EXTERNAL & PUBLIC FUNCTIONS ================
     */

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
                    unwrap(getInternalPriceForTimestamp(block.timestamp)) / ethUsdOracle.getEthUsdPrice(),
                    address(this).balance / unitToken.totalSupply()
                );
        } else {
            return unwrap(getInternalPriceForTimestamp(block.timestamp)) / ethUsdOracle.getEthUsdPrice();
        }
    }

    function mint(address receiver) external payable {}

    // IP(t) = IP(t’) * exp(r(t’) * (t-t’))
    function getInternalPrice() external view returns (uint256) {
        return getInternalPriceForTimestamp(block.timestamp).unwrap();
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

    function getSpread() internal pure returns (uint256) {
        uint256 dynamicSpread; // TODO: This is TBC

        return BASE_SPREAD + dynamicSpread;
    }
}
