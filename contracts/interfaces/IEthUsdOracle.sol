// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IEthUsdOracle {
    function getEthUsdPrice() external view returns (uint256);
}
