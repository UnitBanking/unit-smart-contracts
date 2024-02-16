// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../Timelock.sol';

contract TimelockHarness is Timelock {
    event FallbackIsCalled();

    constructor(uint256 _delay) Timelock(_delay) {}

    function setDelayThroughItself(uint256 _delay) external {
        return this.setDelay(_delay);
    }
}
