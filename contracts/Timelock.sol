// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import './interfaces/ITimelock.sol';
import './abstracts/Ownable.sol';

contract Timelock is ITimelock, Ownable {
    uint public constant GRACE_PERIOD = 14 days;
    uint public constant MINIMUM_DELAY = 2 days;
    uint public constant MAXIMUM_DELAY = 30 days;

    uint public delay;

    mapping(bytes32 => bool) public queuedTransactions;

    constructor(uint _delay) {
        require(_delay >= MINIMUM_DELAY, 'Timelock::constructor: Delay must exceed minimum delay.');
        require(_delay <= MAXIMUM_DELAY, 'Timelock::setDelay: Delay must not exceed maximum delay.');

        delay = _delay;
        _setOwner(msg.sender);
    }

    function setDelay(uint _delay) public {
        require(msg.sender == address(this), 'Timelock::setDelay: Call must come from Timelock.');
        require(_delay >= MINIMUM_DELAY, 'Timelock::setDelay: Delay must exceed minimum delay.');
        require(_delay <= MAXIMUM_DELAY, 'Timelock::setDelay: Delay must not exceed maximum delay.');
        delay = _delay;

        emit NewDelay(_delay);
    }

    function queueTransaction(
        address target,
        uint value,
        string memory signature,
        bytes memory data,
        uint eta
    ) public returns (bytes32) {
        require(msg.sender == owner, 'Timelock::queueTransaction: Call must come from owner.');
        require(
            eta >= (block.timestamp + delay),
            'Timelock::queueTransaction: Estimated execution block must satisfy delay.'
        );

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(
        address target,
        uint value,
        string memory signature,
        bytes memory data,
        uint eta
    ) public {
        require(msg.sender == owner, 'Timelock::cancelTransaction: Call must come from owner.');

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(
        address target,
        uint value,
        string memory signature,
        bytes memory data,
        uint eta
    ) public payable returns (bytes memory) {
        require(msg.sender == owner, 'Timelock::executeTransaction: Call must come from owner.');

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "Timelock::executeTransaction: Transaction hasn't been queued.");
        require(block.timestamp >= eta, "Timelock::executeTransaction: Transaction hasn't surpassed time lock.");
        require(block.timestamp <= (eta + GRACE_PERIOD), 'Timelock::executeTransaction: Transaction is stale.');

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{ value: value }(callData);
        require(success, 'Timelock::executeTransaction: Transaction execution reverted.');

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    fallback() external payable {}

    receive() external payable {}
}
