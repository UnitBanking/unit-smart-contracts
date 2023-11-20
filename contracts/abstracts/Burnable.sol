// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

abstract contract Burnable {
    event BurnableSet(address indexed burner, bool burnable);
    error BurnableDuplicatedOperation();
    error BurnableUnauthorizedAccount(address account);
    mapping(address => bool) public isBurnable;

    function _setBurnable(address burner, bool burnable) internal {
        if (isBurnable[burner] == burnable) {
            revert BurnableDuplicatedOperation();
        }
        isBurnable[burner] = burnable;
        emit BurnableSet(burner, burnable);
    }

    function burn(address account, uint256 amount) external virtual {}
}
