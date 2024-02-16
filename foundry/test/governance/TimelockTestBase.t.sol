// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Test } from 'forge-std/Test.sol';
import { GovernanceHarness } from '../../../contracts/test/GovernanceHarness.sol';
import { IGovernance } from '../../../contracts/interfaces/IGovernance.sol';
import { MineToken } from '../../../contracts/MineToken.sol';
import { Proxy } from '../../../contracts/Proxy.sol';
import { TimelockHarness } from '../../../contracts/test/TimelockHarness.sol';
import { Dummy } from '../../../contracts/test/Dummy.sol';

abstract contract TimelockTestBase is Test {
    uint256 internal constant START_TIMESTAMP = 1699023595;
    uint256 public constant INITIAL_TIMELOCK_DELAY = 3 days;
    TimelockHarness public timelock;
    Dummy public dummy;

    address public wallet = vm.addr(1);

    function setUp() public {
        // set up wallet balance
        vm.deal(wallet, 10 ether);

        // set up block timestamp
        vm.warp(START_TIMESTAMP);

        // set up Timelock contract
        timelock = new TimelockHarness(INITIAL_TIMELOCK_DELAY);
        dummy = new Dummy();

        // set Timelock owner
        timelock.setOwner(wallet);
    }
}
