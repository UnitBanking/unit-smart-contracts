// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../interfaces/IInflationOracle.sol';

contract InflationOracleHarness is IInflationOracle {
    uint256 private priceIndexNow;
    uint256 private priceIndexTwentyYearsAgo;

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
