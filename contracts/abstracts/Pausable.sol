// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

/**
 * @title Pausable contract for pausing and unpausing the contract
 * @notice You can use this contract to control the pause state
 * @dev The modifier onlyNotPaused should be used
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

    /**
     * @notice Set the paused state
     * @dev This function can only be called by the owner
     */
    function setPaused(bool _paused) public virtual {
        _setPaused(_paused);
    }
}
