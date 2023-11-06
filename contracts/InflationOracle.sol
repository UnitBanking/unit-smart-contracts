// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './interfaces/IInflationOracle.sol';

contract InflationOracle is IInflationOracle {
    uint256 private priceIndexNow = 121;
    uint256 private priceIndexTwentyYearsAgo = 77;

    function setLatestPriceIndex(uint256 priceIndex) external {
        priceIndexNow = priceIndex;
    }

    function setPriceIndexTwentyYearsAgo(uint256 priceIndex) external {
        priceIndexTwentyYearsAgo = priceIndex;
    }

    function getLatestPriceIndex() external view returns (uint256) {
        return priceIndexNow;
    }

    function getPriceIndexTwentyYearsAgo() external view returns (uint256) {
        return priceIndexTwentyYearsAgo;
    }
}
