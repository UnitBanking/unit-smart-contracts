// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

abstract contract Mintable {
    event MintableSet(address indexed minter, bool mintable);
    error MintableDuplicatedOperation();
    error MintableUnauthorizedAccount(address account);
    mapping(address => bool) public isMintable;

    function _setMintable(address minter, bool mintable) internal {
        if (isMintable[minter] == mintable) {
            revert MintableDuplicatedOperation();
        }
        isMintable[minter] = mintable;
        emit MintableSet(minter, mintable);
    }

    function mint(address account, uint256 amount) external virtual {}
}