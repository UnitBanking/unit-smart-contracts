// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './interfaces/IInflationOracle.sol';

contract InflationOracle is IInflationOracle {
    function getInflationRate() external pure returns (uint256) {
        return 1;
    }
}
