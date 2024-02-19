// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { TimelockTestBase } from './TimelockTestBase.t.sol';
import { ITimelock } from '../../../contracts/interfaces/ITimelock.sol';

contract TimelockHarnessTest is TimelockTestBase {
    /**
     * ================ constants ================
     */
    function test_constants_HaveCorrectValues() public {
        // Arrange & Act
        uint256 gracePeriod = timelock.GRACE_PERIOD();
        uint256 minDelay = timelock.MINIMUM_DELAY();
        uint256 maxDelay = timelock.MAXIMUM_DELAY();

        // Assert
        assertEq(gracePeriod, 14 days);
        assertEq(minDelay, 2 days);
        assertEq(maxDelay, 30 days);
    }

    /**
     * ================ constructor() ================
     */
    function test_constructor_SuccessfullySetsValues() public {
        // Arrange & Act
        uint256 delay = timelock.delay();

        // Assert
        assertEq(delay, INITIAL_TIMELOCK_DELAY);
    }

    /**
     * ================ setDelay() ================
     */

    function test_setDelay_SuccessfullySetsNewDelay() public {
        // Arrange
        uint256 newDelay = 10 days;
        uint256 oldDelay = timelock.delay();

        // Act
        vm.expectEmit();
        emit ITimelock.DelaySet(newDelay);
        timelock.setDelayThroughItself(newDelay);

        // Assert
        uint256 delay = timelock.delay();
        assertEq(delay, newDelay);
        assertNotEq(delay, oldDelay);
    }

    function test_setDelay_RevertsWhenCallingFromInvalidSender() public {
        // Arrange
        uint256 newDelay = 10 days;

        // Act & Assert
        vm.expectRevert(abi.encodeWithSelector(ITimelock.TimelockInvalidSender.selector, address(this)));
        timelock.setDelay(newDelay);
    }
}
