// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { TimelockTestBase } from './TimelockTestBase.t.sol';
import { ITimelock } from '../../../contracts/interfaces/ITimelock.sol';
import { Ownable } from '../../../contracts/abstracts/Ownable.sol';

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

    /**
     * ================ executeTransaction() ================
     */

    function test_executeTransaction_SuccessfullyExecuteTransaction() public {
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

        // execute transaction
        vm.warp(eta + 1);
        vm.expectEmit();
        emit ITimelock.TransactionExecuted(txHash, target, value, signature, data, eta);
        vm.prank(wallet);
        timelock.executeTransaction(target, value, signature, data, eta);

        // Assert
        assertEq(timelock.queuedTransactions(txHash), false);
        assertEq(timelock.delay(), newDelay);
    }

    function test_executeTransaction_SuccessfullyExecuteTransactionWithDataIncludingSignature() public {
        // Arrange
        uint256 newDelay = 10 days;
        address target = address(timelock);
        uint256 value = 0;
        string memory signature = '';
        bytes memory data = abi.encodePacked(bytes4(keccak256(bytes('setDelay(uint256)'))), abi.encode(newDelay));
        uint256 eta = block.timestamp + 5 days;
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        // Act
        // queue transaction
        vm.prank(wallet);
        timelock.queueTransaction(target, value, signature, data, eta);

        // execute transaction
        vm.warp(eta + 1);
        vm.expectEmit();
        emit ITimelock.TransactionExecuted(txHash, target, value, signature, data, eta);
        vm.prank(wallet);
        timelock.executeTransaction(target, value, signature, data, eta);

        // Assert
        assertEq(timelock.queuedTransactions(txHash), false);
        assertEq(timelock.delay(), newDelay);
    }

    function test_executeTransaction_onDummy_SuccessfullyExecuteTransaction() public {
        // Arrange
        uint256 newNum = 10;
        address target = address(dummy);
        uint256 value = 0;
        string memory signature = 'setNum(uint256)';
        bytes memory data = abi.encode(newNum);
        uint256 eta = block.timestamp + 5 days;
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        // Act
        // queue transaction
        vm.prank(wallet);
        timelock.queueTransaction(target, value, signature, data, eta);

        // execute transaction
        vm.warp(eta + 1);
        vm.expectEmit();
        emit ITimelock.TransactionExecuted(txHash, target, value, signature, data, eta);
        vm.prank(wallet);
        timelock.executeTransaction(target, value, signature, data, eta);

        // Assert
        assertEq(timelock.queuedTransactions(txHash), false);
        assertEq(dummy.num(), newNum);
    }

    function test_executeTransaction_onDummy_SuccessfullyExecuteTransactionWithDataIncludingSignature() public {
        // Arrange
        uint256 newNum = 10;
        address target = address(dummy);
        uint256 value = 0;
        string memory signature = '';
        bytes memory data = abi.encodePacked(bytes4(keccak256(bytes('setNum(uint256)'))), abi.encode(newNum));
        uint256 eta = block.timestamp + 5 days;
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        // Act
        // queue transaction
        vm.prank(wallet);
        timelock.queueTransaction(target, value, signature, data, eta);

        // execute transaction
        vm.warp(eta + 1);
        vm.expectEmit();
        emit ITimelock.TransactionExecuted(txHash, target, value, signature, data, eta);
        vm.prank(wallet);
        timelock.executeTransaction(target, value, signature, data, eta);

        // Assert
        assertEq(timelock.queuedTransactions(txHash), false);
        assertEq(dummy.num(), newNum);
    }

    function test_executeTransaction_SuccessfullyExecuteTransactionWithWrongSignature() public {
        // Arrange
        uint256 oldDelay = timelock.delay();
        uint256 newDelay = 10 days;
        address target = address(timelock);
        uint256 value = 0;
        // string memory correctSignature = 'setDelay(uint256)';
        string memory wrongSignature = 'setDlay(uint256)';
        bytes memory data = abi.encode(newDelay);
        uint256 eta = block.timestamp + 5 days;
        // bytes32 txHashWithCorrectSignature = keccak256(abi.encode(target, value, correctSignature, data, eta));
        bytes32 txHashWithWrongSignature = keccak256(abi.encode(target, value, wrongSignature, data, eta));

        // Act
        // queue transaction
        vm.prank(wallet);
        timelock.queueTransaction(target, value, wrongSignature, data, eta);

        // execute transaction
        vm.warp(eta + 1);
        vm.expectEmit();
        emit ITimelock.TransactionExecuted(txHashWithWrongSignature, target, value, wrongSignature, data, eta);
        vm.prank(wallet);
        timelock.executeTransaction(target, value, wrongSignature, data, eta);

        // Assert
        assertEq(timelock.queuedTransactions(txHashWithWrongSignature), false);
        assertEq(timelock.delay(), oldDelay);
    }

    function test_executeTransaction_onDummy_RevertsWhenCallingWithWrongSignatureAndTargetHasNoFallback() public {
        // Arrange
        uint256 oldNum = dummy.num();
        uint256 newNum = 10;
        address target = address(dummy);
        uint256 value = 0;
        // string memory correctSignature = 'setDelay(uint256)';
        string memory wrongSignature = 'setNm(uint256)';
        bytes memory data = abi.encode(newNum);
        uint256 eta = block.timestamp + 5 days;
        // bytes32 txHashWithCorrectSignature = keccak256(abi.encode(target, value, correctSignature, data, eta));
        bytes32 txHashWithWrongSignature = keccak256(abi.encode(target, value, wrongSignature, data, eta));

        // Act
        // queue transaction
        vm.prank(wallet);
        timelock.queueTransaction(target, value, wrongSignature, data, eta);

        // execute transaction
        vm.warp(eta + 1);
        vm.expectRevert(abi.encodeWithSelector(ITimelock.TimelockTransactionExecutionFailed.selector));
        vm.prank(wallet);
        timelock.executeTransaction(target, value, wrongSignature, data, eta);

        // Assert
        assertEq(timelock.queuedTransactions(txHashWithWrongSignature), true);
        assertEq(dummy.num(), oldNum);
    }

    function test_executeTransaction_RevertsWhenTransactionNotQueued() public {
        // Arrange
        uint256 oldDelay = timelock.delay();
        uint256 newDelay = 10 days;
        address target = address(timelock);
        uint256 value = 0;
        string memory correctSignature = 'setDelay(uint256)';
        string memory wrongSignature = 'setDlay(uint256)';
        bytes memory data = abi.encode(newDelay);
        uint256 eta = block.timestamp + 5 days;
        bytes32 txHashWithCorrectSignature = keccak256(abi.encode(target, value, correctSignature, data, eta));
        // bytes32 txHashWithWrongSignature = keccak256(abi.encode(target, value, wrongSignature, data, eta));

        // Act
        // queue transaction
        vm.prank(wallet);
        timelock.queueTransaction(target, value, correctSignature, data, eta);

        // execute transaction
        vm.warp(eta + 1);
        vm.expectRevert(abi.encodeWithSelector(ITimelock.TimelockTransactionNotQueued.selector));
        vm.prank(wallet);
        timelock.executeTransaction(target, value, wrongSignature, data, eta);

        // Assert
        assertEq(timelock.queuedTransactions(txHashWithCorrectSignature), true);
        assertEq(timelock.delay(), oldDelay);
    }

    function test_executeTransaction_RevertsWhenTimeLockNotSurpassed() public {
        // Arrange
        uint256 oldDelay = timelock.delay();
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

        // execute transaction
        vm.expectRevert(abi.encodeWithSelector(ITimelock.TimelockTransactionTimeLockNotSurpassed.selector));
        vm.prank(wallet);
        timelock.executeTransaction(target, value, signature, data, eta);

        // Assert
        assertEq(timelock.queuedTransactions(txHash), true);
        assertEq(timelock.delay(), oldDelay);
    }

    function test_executeTransaction_RevertsWhenTransactionIsStale() public {
        // Arrange
        uint256 gracePeriod = timelock.GRACE_PERIOD();
        uint256 oldDelay = timelock.delay();
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

        // execute transaction
        vm.warp(eta + gracePeriod + 1);
        vm.expectRevert(abi.encodeWithSelector(ITimelock.TimelockStaleTransaction.selector));
        vm.prank(wallet);
        timelock.executeTransaction(target, value, signature, data, eta);

        // Assert
        assertEq(timelock.queuedTransactions(txHash), true);
        assertEq(timelock.delay(), oldDelay);
    }

    function test_executeTransaction_onDummy_SuccessfullySendEth() public {
        // Arrange
        // send 2 ether to timelock
        vm.prank(wallet);
        (bool success, ) = address(timelock).call{ value: 2 ether }('');
        assertEq(success, true);

        // send 1 ether from timelock to dummy
        address target = address(dummy);
        uint256 value = 1 ether;
        string memory signature = '';
        bytes memory data = '';
        uint256 eta = block.timestamp + 5 days;
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        // Act
        // queue transaction
        vm.prank(wallet);
        timelock.queueTransaction(target, value, signature, data, eta);

        // execute transaction
        vm.warp(eta + 1);
        vm.expectEmit();
        emit ITimelock.TransactionExecuted(txHash, target, value, signature, data, eta);
        vm.prank(wallet);
        timelock.executeTransaction(target, value, signature, data, eta);

        // Assert
        assertEq(timelock.queuedTransactions(txHash), false);
        assertEq(address(dummy).balance, 1 ether);
    }
}
