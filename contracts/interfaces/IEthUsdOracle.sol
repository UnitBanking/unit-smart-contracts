// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IEthUsdOracle {
    /**
     * @notice Returns precision of the prices provided by this oracle.
     */
    function getEthUsdPricePrecision() external view returns (uint256);

    /**
     * @notice Returns the current ETH price in USD.
     * @dev The returned ETH price in USD must match the precision of the UNIT token.
     */
    function getEthUsdPrice() external view returns (uint256);
}
