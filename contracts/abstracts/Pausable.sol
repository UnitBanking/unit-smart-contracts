// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

abstract contract Pausable {
    bool public paused;

    event PausedSet(bool paused);

    error PausableEnforcedPause();
    error PausableSameValueAlreadySet();

    modifier onlyNotPaused() {
        if (paused) {
            revert PausableEnforcedPause();
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
