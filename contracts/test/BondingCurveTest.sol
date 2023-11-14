// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import '../abstracts/BaseToken.sol';
import '../interfaces/IInflationOracle.sol';
import '../interfaces/IEthUsdOracle.sol';
import '../BondingCurve.sol';
import { unwrap } from '@prb/math/src/UD60x18.sol';

contract BondingCurveTest is BondingCurve {
    constructor(
        BaseToken _unitToken,
        IInflationOracle _inflationOracle,
        IEthUsdOracle _ethUsdOracle
    ) BondingCurve(_unitToken, _inflationOracle, _ethUsdOracle) {}

    function testGetInternalPriceForTimestamp(uint256 timestamp) public view returns (uint256) {
        return unwrap(getInternalPriceForTimestamp(timestamp));
    }
}
