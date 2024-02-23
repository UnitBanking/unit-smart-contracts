// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { TimelockTestBase } from './TimelockTestBase.t.sol';
import { ITimelock } from '../../../contracts/interfaces/ITimelock.sol';
import { Ownable } from '../../../contracts/abstracts/Ownable.sol';

contract TimelockHarnessTest is TimelockTestBase {
    /**
     * ================ cancelTransaction() ================
     */

    function test_cancelTransaction_SuccessfullyCancelTransaction() public {
        // Arrange
        uint256 newDelay = 10 days;
        address target = address(timelock);
        uint256 value = 0;
        string memory signature = 'setDelay(uint256)';
        bytes memory data = abi.encode(newDelay);
        uint256 eta = block.timestamp + 5 days;
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        // Act
        // queue transaction
        vm.prank(wallet);
        timelock.queueTransaction(target, value, signature, data, eta);

        // cancel transaction
        vm.expectEmit();
        emit ITimelock.TransactionCanceled(txHash, target, value, signature, data, eta);
        vm.prank(wallet);
        timelock.cancelTransaction(target, value, signature, data, eta);

        // Assert
        assertEq(timelock.queuedTransactions(txHash), false);
    }

    function test_cancelTransaction_RevertsWhenCallingFromNonOwner() public {
        // Arrange
        uint256 newDelay = 10 days;
        address target = address(timelock);
        uint256 value = 0;
        string memory signature = 'setDelay(uint256)';
        bytes memory data = abi.encode(newDelay);
        uint256 eta = block.timestamp + 5 days;
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        // Act & Assert
        // queue transaction
        vm.prank(wallet);
        timelock.queueTransaction(target, value, signature, data, eta);

        // cancel tranaction
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedOwner.selector, address(this)));
        timelock.cancelTransaction(target, value, signature, data, eta);
        assertEq(timelock.queuedTransactions(txHash), true);
    }
}
