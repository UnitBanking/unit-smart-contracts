// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

abstract contract Mintable {
    event MinterSet(address indexed minter, bool canMint);

    error MintableInvalidMinter(address minter);
    error MintableSameValueAlreadySet();
    error MintableUnauthorizedMinter(address minter);

    mapping(address => bool) public isMinter;

    function _setMinter(address minter, bool canMint) internal {
        if (minter == address(0)) {
            revert MintableInvalidMinter(address(0));
        }
        if (isMinter[minter] == canMint) {
            revert MintableSameValueAlreadySet();
        }
        isMinter[minter] = canMint;
        emit MinterSet(minter, canMint);
    }

    function mint(address, uint256) public virtual {
        if (!isMinter[msg.sender]) {
            revert MintableUnauthorizedMinter(msg.sender);
        }
    }
}
