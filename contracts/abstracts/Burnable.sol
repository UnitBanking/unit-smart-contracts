// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

abstract contract Burnable {
    event BurnerSet(address indexed burner, bool canBurn);

    error BurnableSameValueAlreadySet();
    error BurnableUnauthorizedBurner(address burner);

    mapping(address => bool) public isBurner;

    function _setBurner(address burner, bool canBurn) internal {
        if (isBurner[burner] == canBurn) {
            revert BurnableSameValueAlreadySet();
        }
        isBurner[burner] = canBurn;
        emit BurnerSet(burner, canBurn);
    }

    function burn(uint256) public virtual {
        // everyone can burn when address(0) is burner
        if (!isBurner[address(0)] && !isBurner[msg.sender]) {
            revert BurnableUnauthorizedBurner(msg.sender);
        }
    }
}
