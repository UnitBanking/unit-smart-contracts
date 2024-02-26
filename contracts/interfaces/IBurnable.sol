// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IBurnable {
    event BurnerSet(address indexed burner, bool canBurn);

    error BurnableSameValueAlreadySet();
    error BurnableInvalidTokenOwner(address tokenOwner);
    error BurnableUnauthorizedBurner(address burner);

    function isBurner(address burner) external returns (bool canBurn);

    function burn(uint256 amount) external;

    function burnFrom(address from, uint256 amount) external;
}
