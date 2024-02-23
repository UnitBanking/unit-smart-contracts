// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../interfaces/IBurnable.sol';

/**
 * @dev IMPORTANT: This contract is used as parent contract in contracts that implement a proxy pattern.
 * Adding, removing, changing or rearranging state variables in this contract can result in a storage collision
 * in child contracts in case of a contract upgrade.
 */
abstract contract Burnable is IBurnable {

    mapping(address burner => bool canBurn) public isBurner;

    function _setBurner(address burner, bool canBurn) internal {
        if (isBurner[burner] == canBurn) {
            revert BurnableSameValueAlreadySet();
        }
        isBurner[burner] = canBurn;
        emit BurnerSet(burner, canBurn);
    }

    function burn(uint256 /* amount */) public virtual {
        _canBurn(msg.sender);
    }

    function burnFrom(address from, uint256 /* amount */) public virtual {
        if (from == address(0)) {
            revert BurnableInvalidTokenOwner(address(0));
        }
        _canBurn(msg.sender);
    }

    function _canBurn(address burner) private view {
        // everyone can burn when address(0) is burner
        if (!isBurner[address(0)] && !isBurner[burner]) {
            revert BurnableUnauthorizedBurner(burner);
        }
    }
}
