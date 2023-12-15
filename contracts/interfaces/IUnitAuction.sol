// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IUnitAuction {
    function sellUnit(uint256 unitAmount) external;

    function buyUnit(uint256 collateralAmount) external;
}
