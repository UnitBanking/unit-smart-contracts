// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import './interfaces/ITimelock.sol';
import './abstracts/Ownable.sol';

contract Timelock is ITimelock, Ownable {
    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MINIMUM_DELAY = 2 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;

    uint256 public delay;

    mapping(bytes32 => bool) public queuedTransactions;

    constructor(uint256 _delay) {
        if (_delay < MINIMUM_DELAY || _delay > MAXIMUM_DELAY) {
            revert TimelockInvalidDelay();
        }

        delay = _delay;
        _setOwner(msg.sender);
    }

    function setDelay(uint256 _delay) public {
        if (msg.sender != address(this)) {
            revert TimelockInvalidSender(msg.sender);
        }
        if (_delay < MINIMUM_DELAY || _delay > MAXIMUM_DELAY) {
            revert TimelockInvalidDelay();
        }
        delay = _delay;

        emit NewDelay(_delay);
    }

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public onlyOwner returns (bytes32) {
        if (eta < block.timestamp + delay) {
            revert TimelockInvalidEta();
        }

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public onlyOwner {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public payable onlyOwner returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        if (!queuedTransactions[txHash]) {
            revert TimelockTransactionNotQueued();
        }
        if (block.timestamp < eta) {
            revert TimelockTransactionTimeLockNotSurpassed();
        }
        if (block.timestamp > eta + GRACE_PERIOD) {
            revert TimelockStaleTransaction();
        }

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{ value: value }(callData);
        if (!success) {
            revert TimelockTransactionExecutionFailed();
        }

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    fallback() external payable {}

    receive() external payable {}
}
