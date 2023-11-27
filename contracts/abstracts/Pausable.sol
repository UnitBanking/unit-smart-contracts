// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

abstract contract Pausable {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    error PausableEnforcedPause();
    error PausableExpectedPause();

    constructor() {
        _paused = false;
    }

    modifier whenNotPaused() {
        if (_paused) {
            revert PausableEnforcedPause();
        }
        _;
    }

    modifier whenPaused() {
        if (!_paused) {
            revert PausableExpectedPause();
        }
        _;
    }

    function paused() public view virtual returns (bool) {
        return _paused;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}
