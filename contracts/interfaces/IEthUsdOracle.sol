// SPDX-License-Identifier: MIT
// Deployed with donations via Gitcoin GR9

pragma solidity 0.8.21;

interface IEthUsdOracle {
    function getEthUsdPrice() external pure returns (uint256);
}
