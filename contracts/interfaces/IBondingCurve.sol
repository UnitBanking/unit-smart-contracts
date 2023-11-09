// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IBondingCurve {
    function updateInternals() external;

    function getInternalPrice() external view returns (uint256);

    function getUnitEthPrice() external view returns (uint256);

    function mint(address receiver) external payable;

    function burn() external;

    function getReserveRatio() external view returns (uint256);
}
