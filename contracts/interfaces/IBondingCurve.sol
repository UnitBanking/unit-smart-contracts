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

    function mint(address receiver) external payable;

    function burn(uint256 unitTokenAmount) external;

    function redeem(uint256 mineTokenAmount) external;

    function updateInternals() external;

    /**
     * ================ GETTERS ================
     */

    function getInternalPrice() external view returns (uint256);

    function getUnitEthPrice() external view returns (uint256);

    function getReserveRatio() external view returns (uint256);

    function getExcessEthReserve() external view returns (uint256);
}
