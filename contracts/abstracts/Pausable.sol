// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

/**
 * @title Pausable contract for pausing and unpausing the contract
 * @notice You can use this contract to control the pause state
 * @dev The modifier onlyNotPaused should be used
 */
abstract contract Pausable {
    uint256 public paused = 1;

    event PausedSet(bool paused);

    error PausableContractIsPaused();
    error PausableSameValueAlreadySet();

    modifier onlyNotPaused() {
        if (paused == 2) {
            revert PausableContractIsPaused();
        }
        _;
    }

    function _setPaused(uint256 _paused) internal {
        if (paused == _paused) {
            revert PausableSameValueAlreadySet();
        }
        paused = _paused;
    }

    /**
     * @notice Set as paused
     * @dev This function can only be called by the owner
     */
    function setPaused(bool _paused) public virtual {
        _setPaused(_paused ? 2 : 1);
        emit PausedSet(_paused);
    }
}
