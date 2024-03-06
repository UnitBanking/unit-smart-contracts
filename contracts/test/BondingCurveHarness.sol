// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../interfaces/IERC20.sol';
import '../interfaces/IInflationOracle.sol';
import '../interfaces/ICollateralUsdOracle.sol';
import '../BondingCurve.sol';
import { unwrap } from '@prb/math/src/UD60x18.sol';

contract BondingCurveHarness is BondingCurve {
    constructor(
        IERC20 _collateralToken,
        address collateralBurnAddress
    ) BondingCurve(_collateralToken, collateralBurnAddress) {}

    function exposed_getUnitUsdPriceForTimestamp(uint256 timestamp) public view returns (uint256) {
        return unwrap(_getUnitUsdPriceForTimestamp(timestamp));
    }
}
