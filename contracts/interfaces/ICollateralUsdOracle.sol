// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface ICollateralUsdOracle {
    /**
     * @notice Returns precision of the prices provided by this oracle.
     */
    function getCollateralUsdPricePrecision() external view returns (uint256);

    /**
     * @notice Returns the current collateral token price in USD.
     * @dev The returned collateral price in USD must match the precision of the UNIT token.
     */
    function getCollateralUsdPrice() external view returns (uint256);
}
