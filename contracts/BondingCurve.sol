// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import './interfaces/IBondingCurve.sol';
import './interfaces/IERC20.sol';
import './interfaces/IInflationOracle.sol';
import './interfaces/IEthUsdOracle.sol';
import { exp } from "@prb/math/ud60x18/Math.sol";
import './libraries/Math.sol';

/*
      UD60x18 value = UD60x18.wrap(100000000000000); // e^0.0001
      UD60x18 result = value.exp();
      uint256 resultUint = UD60x18.unwrap(result);
*/
/*
 TODOs:
 - reduce OpenZeppelin Math library (we only need min/max funcs ATM)
 - find which math lib is a better fit (ABDKMathQuad, PRB-Math, etc.)
 - update function visibility as appropriate
 */

contract BondingCurve is IBondingCurve {
    uint256 private constant TWENTY_YEARS_IN_SECONDS = 20 * 365 days;
    uint256 private constant TWENTY_YEARS = 20;
    uint256 private constant ONE_YEAR_IN_SECONDS = 365 days;
    uint256 public constant SPREAD_PRECISION = 1000;
    uint256 public constant BASE_SPREAD = 1;

    bytes16 public lastInternalPrice; // IP(t')
    uint256 public lastOracleInflationRate; // r(t') = min(100%, max(0, (ln(Index(t’)) – ln(Index(t’- 20years))/20years))
    uint256 public lastOracleUpdateTimestamp; // t'

    IInflationOracle public inflationOracle;
    IEthUsdOracle public ethUsdOracle;
    IERC20 public unitToken;

    constructor(IERC20 _unitToken, IInflationOracle _inflationOracle, IEthUsdOracle _ethUsdOracle) {
        lastInternalPrice = ABDKMathQuad.fromUInt(1);

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
        return
            lastInternalPrice
                .mul(
                    ABDKMathQuad.exp(
                        ABDKMathQuad.fromUInt(lastOracleInflationRate).mul(
                            (
                                ABDKMathQuad.fromUInt(block.timestamp).sub(
                                    ABDKMathQuad.fromUInt(lastOracleUpdateTimestamp)
                                )
                            ).div(ABDKMathQuad.fromUInt(ONE_YEAR_IN_SECONDS))
                        )
                    )
                )
                .toUInt();
    }

    function updateInternals() public {
        (uint256 currentPriceIndex, uint256 currentOracleUpdateTimestamp) = inflationOracle.getLatestPriceIndex();
        uint256 pastPriceIndex = inflationOracle.getPastPriceIndex(
            currentOracleUpdateTimestamp - (block.timestamp - TWENTY_YEARS_IN_SECONDS)
        );
        uint256 priceIndexDelta = ABDKMathQuad.toUInt(
            ABDKMathQuad
                .sub(
                    ABDKMathQuad.ln(ABDKMathQuad.fromUInt(currentPriceIndex)),
                    ABDKMathQuad.ln(ABDKMathQuad.fromUInt(pastPriceIndex))
                )
                .div(ABDKMathQuad.fromUInt(TWENTY_YEARS))
        );

        lastInternalPrice = lastInternalPrice.mul(
            ABDKMathQuad.exp(
                ABDKMathQuad.fromUInt(lastOracleInflationRate).mul(
                    (
                        ABDKMathQuad.fromUInt(currentOracleUpdateTimestamp).sub(
                            ABDKMathQuad.fromUInt(lastOracleUpdateTimestamp)
                        )
                    ).div(ABDKMathQuad.fromUInt(ONE_YEAR_IN_SECONDS))
                )
            )
        );
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
