// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IEthUsdOracle {
    /**
     * @dev The returned ETH price in USD must match the precision of the UNIT token.
     */
    function getEthUsdPrice() external view returns (uint256);
}
