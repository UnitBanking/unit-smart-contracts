// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import '../interfaces/IERC20.sol';
import '../interfaces/IInflationOracle.sol';
import '../interfaces/IEthUsdOracle.sol';
import '../BondingCurve.sol';

contract BondingCurveTest is BondingCurve {
    constructor(
        IERC20 _unitToken,
        IInflationOracle _inflationOracle,
        IEthUsdOracle _ethUsdOracle
    ) BondingCurve(_unitToken, _inflationOracle, _ethUsdOracle) {}

    function testGetInternalPriceForTimestamp(uint256 timestamp) public view returns (uint256) {
        return getInternalPriceForTimestamp(timestamp);
    }
}
