// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './interfaces/IInflationOracle.sol';

contract InflationOracle is IInflationOracle {
    function getLatestPriceIndex() external view returns (uint256, uint256) {
        return (1, block.timestamp);
    }

    function getPriceIndexForTimestamp(uint256 pastTimestamp) external pure returns (uint256) {
        return 1;
    }
}
