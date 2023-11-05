// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import './interfaces/IBondingCurve.sol';
import './interfaces/IERC20.sol';
import './interfaces/IInflationOracle.sol';
import './interfaces/IEthUsdOracle.sol';
import { UD60x18, ud, convert, uUNIT } from '@prb/math/src/UD60x18.sol';
import { exp, ln } from '@prb/math/src/ud60x18/Math.sol';
import './libraries/Math.sol';

import 'hardhat/console.sol';

/*
 TODOs:
 - reduce OpenZeppelin Math library (we only need min/max funcs ATM)
 - update function visibility as appropriate
 */

contract BondingCurve is IBondingCurve {
    uint256 private constant TWENTY_YEARS_IN_SECONDS = 20 * 365 days;
    UD60x18 private constant TWENTY_YEARS_UD60x18 = UD60x18.wrap(20 * uUNIT);
    UD60x18 private constant ONE_YEAR_IN_SECONDS_UD60x18 = UD60x18.wrap(365 days * uUNIT);
    uint256 public constant SPREAD_PRECISION = 1000;
    uint256 public constant BASE_SPREAD = 1;
    uint256 public constant PRB_MATH_PRECISION = 1e18;

    uint256 public lastInternalPrice; // IP(t')
    uint256 public lastOracleInflationRate; // r(t') = min(100%, max(0, (ln(Index(t’)) – ln(Index(t’- 20years))/20years))
    uint256 public lastOracleUpdateTimestamp; // t'

    IInflationOracle public inflationOracle;
    IEthUsdOracle public ethUsdOracle;
    IERC20 public unitToken;

    constructor(IERC20 _unitToken, IInflationOracle _inflationOracle, IEthUsdOracle _ethUsdOracle) {
        lastInternalPrice = 1;

        unitToken = _unitToken;
        inflationOracle = _inflationOracle;
        ethUsdOracle = _ethUsdOracle;

        updateInternals();
    }

    // mintPrice = P(t) * (1 + spread(t))
    function getMintPrice() public returns (uint256) {}

    // P(t) = min(IP(t)/EP(t), BalanceETH(t)/SupplyUnit(t))
    function getUnitEthPrice() public view returns (uint256) {
        uint256 unitTotalSupply = unitToken.totalSupply();
        if (unitTotalSupply > 0) {
            return
                Math.min(
                    getInternalPrice() / ethUsdOracle.getEthUsdPrice(),
                    address(this).balance / unitToken.totalSupply()
                );
        } else {
            return getInternalPrice() / ethUsdOracle.getEthUsdPrice();
        }
    }

    // IP(t) = IP(t’) * exp(r(t’) * (t-t’))
    function getInternalPrice() public view returns (uint256) {
        return getInternalPriceForTimestamp(block.timestamp);
    }

    function getInternalPriceForTimestamp(uint256 timestamp) internal view returns (uint256) {
        return
            lastInternalPrice *
            convert(
                exp(
                    convert(lastOracleInflationRate).mul(
                        convert(timestamp - lastOracleUpdateTimestamp).div(ONE_YEAR_IN_SECONDS_UD60x18)
                    )
                )
            );
    }

    function updateInternals() public {
        (uint256 currentPriceIndex, uint256 currentOracleUpdateTimestamp) = inflationOracle.getLatestPriceIndex();

        uint256 pastPriceIndex = inflationOracle.getPriceIndexForTimestamp(
            currentOracleUpdateTimestamp - TWENTY_YEARS_IN_SECONDS
        );

        uint256 priceIndexDelta = convert(
            (ln(convert(currentPriceIndex)).sub(ln(convert(pastPriceIndex)))).div(TWENTY_YEARS_UD60x18)
        );

        lastInternalPrice = getInternalPriceForTimestamp(currentOracleUpdateTimestamp);
        lastOracleInflationRate = Math.min(100, Math.max(0, priceIndexDelta));
        lastOracleUpdateTimestamp = currentOracleUpdateTimestamp;
    }

    // function mint(address receiver) external payable {
    // }

    function getSpread() internal pure returns (uint256) {
        uint256 dynamicSpread; // TODO: This is TBC

        return BASE_SPREAD + dynamicSpread;
    }
}
