// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import '../interfaces/IERC20.sol';
import '../interfaces/IInflationOracle.sol';
import '../interfaces/IEthUsdOracle.sol';
import '../BondingCurve.sol';
import { unwrap } from '@prb/math/src/UD60x18.sol';

contract BondingCurveHarness is BondingCurve {
    constructor(
        address _unitToken,
        address _mineToken,
        IInflationOracle _inflationOracle,
        IEthUsdOracle _ethUsdOracle
    ) BondingCurve(_unitToken, _mineToken, _inflationOracle, _ethUsdOracle) {}

    function exposed_getInternalPriceForTimestamp(uint256 timestamp) public view returns (uint256) {
        return unwrap(_getInternalPriceForTimestamp(timestamp));
    }
}
