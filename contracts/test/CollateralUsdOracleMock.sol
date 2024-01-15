// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import '../interfaces/ICollateralUsdOracle.sol';

contract CollateralUsdOracleMock is ICollateralUsdOracle {
    uint256 private constant COLLATERALUSD_PRICE_PRECISION = 1e18;
    uint256 collateralUsdPrice;

    constructor() {
        collateralUsdPrice = COLLATERALUSD_PRICE_PRECISION;
    }

    function getCollateralUsdPricePrecision() external pure returns (uint256) {
        return COLLATERALUSD_PRICE_PRECISION;
    }

    function setCollateralUsdPrice(uint256 _collateralUsdPrice) external {
        collateralUsdPrice = _collateralUsdPrice;
    }

    function getCollateralUsdPrice() external view returns (uint256) {
        return collateralUsdPrice;
    }
}
