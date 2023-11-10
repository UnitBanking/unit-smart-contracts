// SPDX-License-Identifier: MIT
// Deployed with donations via Gitcoin GR9

pragma solidity 0.8.21;

interface IInflationOracle {
    function getInflationRate() external pure returns (uint256);
}
