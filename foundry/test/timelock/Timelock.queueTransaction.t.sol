// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { TimelockTestBase } from './TimelockTestBase.t.sol';
import { ITimelock } from '../../../contracts/interfaces/ITimelock.sol';
import { Ownable } from '../../../contracts/abstracts/Ownable.sol';

contract TimelockHarnessTest is TimelockTestBase {
    /**
     * ================ queueTransaction() ================
     */

    function test_queueTransaction_SuccessfullyQueueTransaction() public {
        // Arrange
        uint256 newDelay = 10 days;
        address target = address(timelock);
        uint256 value = 0;
        string memory signature = 'setDelay(uint256)';
        bytes memory data = abi.encode(newDelay);
        uint256 eta = block.timestamp + 5 days;
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        // Act
        vm.expectEmit();
        emit ITimelock.TransactionQueued(txHash, target, value, signature, data, eta);
        vm.startPrank(wallet);
        bytes32 returnedTxHash = timelock.queueTransaction(target, value, signature, data, eta);

        // Assert
        assertEq(returnedTxHash, txHash);
        assertEq(timelock.queuedTransactions(txHash), true);
    }

    function test_queueTransaction_RevertsWhenCallingFromNonOwner() public {
        // Arrange
        uint256 newDelay = 10 days;
        address target = address(timelock);
        uint256 value = 0;
        string memory signature = 'setDelay(uint256)';
        bytes memory data = abi.encode(newDelay);
        uint256 eta = block.timestamp + 5 days;
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        // Act & Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedOwner.selector, address(this)));
        timelock.queueTransaction(target, value, signature, data, eta);
        assertEq(timelock.queuedTransactions(txHash), false);
    }

    function test_queueTransaction_RevertsWhenEtaIsTooSmall() public {
        // Arrange
        uint256 newDelay = 10 days;
        address target = address(timelock);
        uint256 value = 0;
        string memory signature = 'setDelay(uint256)';
        bytes memory data = abi.encode(newDelay);
        uint256 eta = 5 days;
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        // Act & Assert
        vm.expectRevert(abi.encodeWithSelector(ITimelock.TimelockInvalidEta.selector));
        vm.startPrank(wallet);
        timelock.queueTransaction(target, value, signature, data, eta);
        assertEq(timelock.queuedTransactions(txHash), false);
    }
}
