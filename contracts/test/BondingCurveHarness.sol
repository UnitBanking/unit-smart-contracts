// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../BondingCurve.sol';
import { unwrap } from '@prb/math/src/UD60x18.sol';

contract BondingCurveHarness is BondingCurve {
    constructor(
        IUnitToken _unitToken,
        IMineToken _mineToken,
        IERC20 _collateralToken,
        address collateralBurnAddress,
        IInflationOracle _inflationOracle,
        ICollateralUsdOracle _collateralUsdOracle
    )
        BondingCurve(
            _unitToken,
            _mineToken,
            _collateralToken,
            collateralBurnAddress,
            _inflationOracle,
            _collateralUsdOracle
        )
    {}

    function exposed_getUnitUsdPriceForTimestamp(uint256 timestamp) external view returns (uint256) {
        return unwrap(_getUnitUsdPriceForTimestamp(timestamp));
    }

    function exposed_collateralTokenDecimals() external view returns (uint256) {
        return collateralTokenDecimals;
    }
}
