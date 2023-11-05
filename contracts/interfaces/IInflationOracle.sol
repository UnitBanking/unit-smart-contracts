// SPDX-License-Identifier: MIT
// Deployed with donations via Gitcoin GR9

pragma solidity 0.8.21;

interface IInflationOracle {
    function getLatestPriceIndex() external view returns (uint256 latestPriceIndex, uint256 timestamp);

    function getPriceIndexForTimestamp(uint256 pastTimestamp) external pure returns (uint256 pastPriceIndex);
}
