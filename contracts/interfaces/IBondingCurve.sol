// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IBondingCurve {
    /**
     * ================ ERRORS ================
     */
    error BondingCurveInvalidReceiver(address receiver);
    error BondingCurveMintDisabledDueToTooLowRR();

    /**
     * ================ CORE FUNCTIONALITY ================
     */

    /**
     * @notice Allows to mint UNIT token to the specified receiver by providing ETH.
     * @dev This function can only by called by UNIT token minter. See {UnitToken-mint}.
     * @param receiver The receiver of minted UNIT tokens.
     */
    function mint(address receiver) external payable;

    /**
     * @notice Allows to redeem ETH by burning UNIT token.
     * @param unitTokenAmount UNIT token amount to be burned.
     */
    function burn(uint256 unitTokenAmount) external;

    /**
     * @notice Allows to redeem a portion of excess ETH by burning MINE token.
     * @param mineTokenAmount MINE token amount to be burned.
     */
    function redeem(uint256 mineTokenAmount) external;

    /**
     * @dev Updates the values for {lastInternalPrice}, {lastOracleInflationRate}, and {lastOracleUpdateTimestamp}.
     */
    function updateInternals() external;

    /**
     * ================ GETTERS ================
     */

    function getInternalPrice() external view returns (uint256);

    function getUnitEthPrice() external view returns (uint256);

    function getReserveRatio() external view returns (uint256);

    function getExcessEthReserve() external view returns (uint256);
}
