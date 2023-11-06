// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

uint256 constant PRICE_INDEX_PRECISION = 100_000;

interface IInflationOracle {
    function setLatestPriceIndex(uint256 priceIndex) external;

    function setPriceIndexTwentyYearsAgo(uint256 priceIndex) external;

    function getLatestPriceIndex() external view returns (uint256 latestPriceIndex);

    function getPriceIndexTwentyYearsAgo() external view returns (uint256 pastPriceIndex);
}
