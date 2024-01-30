// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

/**
 * @dev IMPORTANT: This contract is used as parent contract in contracts that implement a proxy pattern.
 * Adding, removing, changing or rearranging state variables in this contract can result in a storage collision
 * in child contracts in case of a contract upgrade.
 */
abstract contract Pausable {
    bool public paused;

    event PausedSet(bool paused);

    error PausableContractIsPaused();
    error PausableSameValueAlreadySet();

    modifier onlyNotPaused() {
        if (paused) {
            revert PausableContractIsPaused();
        }
        _;
    }

    function _setPaused(bool _paused) internal {
        if (paused == _paused) {
            revert PausableSameValueAlreadySet();
        }
        paused = _paused;
        emit PausedSet(_paused);
    }

    function setPaused(bool _paused) public virtual {
        _setPaused(_paused);
    }
}
