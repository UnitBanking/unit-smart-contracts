// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface ITimelock {
    /**
     * ================ EVENTS ================
     */
    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 indexed newDelay);
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    /**
     * ================ ERRORS ================
     */

    /// @notice Thrown when a call didn't come from the Timelock contract itself.
    error TimelockInvalidSender(address sender);

    /// @notice Thrown when the delay is out of bound.
    error TimelockInvalidDelay();

    /// @notice Thrown when the estimated execution block (eta) does not satisfy the delay.
    error TimelockInvalidEta();

    /// @notice Thrown when the transaction hasn't been queued.
    error TimelockTransactionNotQueued();

    /// @notice Thrown when the transaction hasn't surpassed its time lock.
    error TimelockTransactionTimeLockNotSurpassed();

    /// @notice Thrown when the transaction is stale.
    error TimelockStaleTransaction();

    /// @notice Thrown when the transaction execution reverted.
    error TimelockTransactionExecutionFailed();

    /**
     * ================ GETTERS ================
     */
    function delay() external view returns (uint);

    function GRACE_PERIOD() external view returns (uint);

    function queuedTransactions(bytes32 hash) external view returns (bool);

    /**
     * ================ CORE FUNCTIONALITY ================
     */

    /**
     * @notice Queues a transaction for a future execution.
     * @param target Target address for the transaction.
     * @param value Eth value for the transaction.
     * @param signature Function signature for the transaction.
     * @param data Calldata for the transaction.
     * @param eta Timestamp that the transaction will be available for execution.
     * @return Transaction hash
     */
    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes32);

    /**
     * @notice Cancels a previously queued transaction.
     * @param target Target address for the transaction.
     * @param value Eth value for the transaction.
     * @param signature Function signature for the transaction.
     * @param data Calldata for the transaction.
     * @param eta Timestamp that the transaction will be available for execution.
     */
    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external;

    /**
     * @notice Executes a previously queued transaction.
     * @param target Target address for the transaction.
     * @param value Eth value for the transaction.
     * @param signature Function signature for the transaction.
     * @param data Calldata for the transaction.
     * @param eta Timestamp that the transaction will be available for execution.
     * @return Data returned from a low-level call.
     */
    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external payable returns (bytes memory);
}
