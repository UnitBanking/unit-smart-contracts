// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../interfaces/IMintable.sol';

/**
 * @dev IMPORTANT: This contract is used as parent contract in contracts that implement a proxy pattern.
 * Adding, removing, changing or rearranging state variables in this contract can result in a storage collision
 * in child contracts in case of a contract upgrade.
 */
abstract contract Mintable is IMintable {
    mapping(address minter => bool canMint) public isMinter;

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

    function mint(address receiver, uint256 /* amount */) public virtual {
        if (receiver == address(0)) {
            revert MintableInvalidReceiver(address(0));
        }
        if (!isMinter[msg.sender]) {
            revert MintableUnauthorizedMinter(msg.sender);
        }
    }
}
