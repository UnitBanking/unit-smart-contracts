// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

// The FED's report presents the price index with 3 decimal places (see https://fred.stlouisfed.org/series/PCEPI).
// We are including two additional digits of precision as a precaution.
uint256 constant PRICE_INDEX_PRECISION = 100_000;

interface IInflationOracle {
    function setLatestPriceIndex(uint256 priceIndex) external;

    function setPriceIndexTwentyYearsAgo(uint256 priceIndex) external;

    function getLatestPriceIndex() external view returns (uint256 latestPriceIndex);

    function getPriceIndexTwentyYearsAgo() external view returns (uint256 pastPriceIndex);
}
