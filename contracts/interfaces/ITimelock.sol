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

    /// @notice Thrown when delay is out of bound.
    error TimelockInvalidDelay();

    /// @notice Thrown when an estimated execution block (eta) does not satisfy delay.
    error TimelockInvalidEta();

    /// @notice Thrown when a transaction hasn't been queued.
    error TimelockTransactionNotQueued();

    /// @notice Thrown when a transaction hasn't surpassed its time lock.
    error TimelockTransactionTimeLockNotSurpassed();

    /// @notice Thrown when a transaction is stale.
    error TimelockStaleTransaction();

    /// @notice Thrown when a transaction execution reverted.
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

    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes32);

    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external;

    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external payable returns (bytes memory);
}
