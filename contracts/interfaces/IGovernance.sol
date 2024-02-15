// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IGovernance {
    /**
     * ================ STRUCTS ================
     */
    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint256 id;
        /// @notice Creator of the proposal
        address proposer;
        /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint256 eta;
        /// @notice the ordered list of target addresses for calls to be made
        address[] targets;
        /// @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint256[] values;
        /// @notice The ordered list of function signatures to be called
        string[] signatures;
        /// @notice The ordered list of calldata to be passed to each call
        bytes[] calldatas;
        /// @notice The block at which voting begins: holders must delegate their votes prior to this block
        uint256 startBlock;
        /// @notice The block at which voting ends: votes must be cast prior to this block
        uint256 endBlock;
        /// @notice Current number of votes in favor of this proposal
        uint256 forVotes;
        /// @notice Current number of votes in opposition to this proposal
        uint256 againstVotes;
        /// @notice Current number of votes for abstaining for this proposal
        uint256 abstainVotes;
        /// @notice Flag marking whether the proposal has been canceled
        bool canceled;
        /// @notice Flag marking whether the proposal has been executed
        bool executed;
        /// @notice Receipts of ballots for the entire set of voters
        mapping(address => Receipt) receipts;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        /// @notice Whether or not a vote has been cast
        bool hasVoted;
        /// @notice Whether or not the voter supports the proposal or abstains
        uint8 support;
        /// @notice The number of votes the voter had, which were cast
        uint96 votes;
    }

    /**
     * ================ ENUMS ================
     */

    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    /**
     * ================ CORE FUNCTIONALITY ================
     */

    /**
     * @notice Initializes the Governance contract
     * @dev Owner only. Deploy timelock contract which initializes the contract
     * @param _votingPeriod The initial voting period
     * @param _votingDelay The initial voting delay
     * @param _proposalThreshold The initial proposal threshold
     * @param _timelockDelay The initial timelock delay
     */
    function initialize(
        uint256 _votingPeriod,
        uint256 _votingDelay,
        uint256 _proposalThreshold,
        uint256 _timelockDelay
    ) external;

    /**
     * @notice Function used to propose a new proposal. Sender must have delegates above the proposal threshold
     * @param targets Target addresses for proposal calls
     * @param values Eth values for proposal calls
     * @param signatures Function signatures for proposal calls
     * @param calldatas Calldatas for proposal calls
     * @param description String description of the proposal
     * @return Proposal id of new proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);

    /**
     * @notice Queues a proposal of state succeeded
     * @param proposalId The id of the proposal to queue
     */
    function queue(uint256 proposalId) external;

    /**
     * @notice Executes a queued proposal if eta has passed
     * @param proposalId The id of the proposal to execute
     */
    function execute(uint256 proposalId) external payable;

    /**
     * @notice Cancels a proposal only if sender is the proposer, or proposer delegates dropped below proposal threshold
     * @param proposalId The id of the proposal to cancel
     */
    function cancel(uint256 proposalId) external;

    /**
     * @notice Cast a vote for a proposal
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     */
    function castVote(uint256 proposalId, uint8 support) external;

    /**
     * @notice Cast a vote for a proposal with a reason
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @param reason The reason given for the vote by the voter
     */
    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external;

    /**
     * @notice Cast a vote for a proposal by signature
     * @dev External function that accepts EIP-712 signatures for voting on proposals.
     */
    function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external;

    /**
     * ================ EVENTS ================
     */

    /// @notice An event emitted when a new proposal is created
    event ProposalCreated(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    /**
     * @notice An event emitted when a vote has been cast on a proposal
     * @param voter The address which casted a vote
     * @param proposalId The proposal id which was voted on
     * @param support Support value for the vote. 0=against, 1=for, 2=abstain
     * @param votes Number of votes which were cast by the voter
     * @param reason The reason given for the vote by the voter
     */
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 votes, string reason);

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint256 id);

    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint256 id, uint256 eta);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint256 id);

    /// @notice An event emitted when the voting delay is set
    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);

    /// @notice An event emitted when the voting period is set
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);

    /// @notice Emitted when proposal threshold is set
    event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);

    /// @notice Emitted when whitelist account expiration is set
    event WhitelistAccountExpirationSet(address account, uint256 expiration);

    /// @notice Emitted when the whitelistGuardian is set
    event WhitelistGuardianSet(address oldGuardian, address newGuardian);

    /**
     * ================ ERRORS ================
     */

    /// @notice Thrown when proposer votes below proposal threshold.
    error GovernanceVotesBelowProposalThreshold();

    /// @notice Thrown when proposer votes above proposal threshold.
    error GovernanceVotesAboveProposalThreshold();

    /// @notice Thrown when proposal function information arity mismatch.
    error GovernanceArityMismatch();

    /// @notice Thrown when no actions provided in a proposal.
    error GovernanceNoActions();

    /// @notice Thrown when too many actions provided in a proposal.
    error GovernanceTooManyActions();

    /// @notice Throw when found an already active proposal. Only one live proposal per proposer is allowed.
    error GovernanceOnlyOneActiveProposalAllowed();

    /// @notice Throw when found an already pending proposal. Only one live proposal per proposer is allowed.
    error GovernanceOnlyOnePendingProposalAllowed();

    /// @notice Thrown when the proposal is in a state other than required.
    error GovernanceInvalidProposalState(ProposalState requiredState, ProposalState actualState);

    /// @notice Thrown when the proposal id is out of bound.
    error GovernanceInvalidProposalId();

    /// @notice Thrown when an identical proposal action is already queued at eta.
    error GovernanceDuplicatedProposal();

    /// @notice Thrown when trying to cancel an already executed proposal.
    error GovernanceProposalAlreadyExecuted();

    /// @notice Thrown when the signature is invalid.
    error GovernanceInvalidDelegateSignature();

    /// @notice Thrown when voting is closed.
    error GovernanceVotingClosed();

    /// @notice Thrown when the provided vote type is invalid.
    error GovernanceInvalidVoteType();

    /// @notice Thrown when the voter has already voted.
    error GovernanceVoterAlreadyVoted();

    /// @notice Thrown when the voting period is outside the minimum or maximum voting period.
    error GovernanceInvalidVotingPeriod();

    /// @notice Thrown when the proposal threshold is outside the minimum or maximum threshold.
    error GovernanceInvalidProposalThreshold();

    /// @notice Thrown when the voting delay is outside the minimum or maximum voting delay.
    error GovernanceInvalidVotingDelay();

    /// @notice Thrown when an unauthorized sender tries to call an admin function.
    error GovernanceUnauthorizedSender(address sender);

    /// @notice Thrown when an unauthorized sender tries to cancel a proposal proposed by whitelisted proposor.
    error GovernanceOnlyWhitelistGuardianCanCancelProposalWithVotesBelowThreshold();
}
