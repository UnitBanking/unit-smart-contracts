// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IEthUsdOracle {
    /**
     * @dev The returned ETH price in USD must have 18 decimals.
     */
    function getEthUsdPrice() external view returns (uint256);
}
