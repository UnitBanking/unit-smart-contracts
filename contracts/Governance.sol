// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './interfaces/IGovernance.sol';
import './interfaces/ITimelock.sol';
import './interfaces/IVote.sol';
import './abstracts/Proxiable.sol';
import './abstracts/Ownable.sol';
import './Timelock.sol';

/**
 * @dev IMPORTANT: This contract implements a proxy pattern. Do not modify inheritance list in this contract.
 * Adding, removing, changing or rearranging these base contracts can result in a storage collision after a contract upgrade.
 */
contract Governance is IGovernance, Proxiable, Ownable {
    /**
     * ================ CONSTANTS ================
     */

    /// @notice The name of this contract
    string public constant name = 'Mine Governance';

    /// @notice The minimum setable proposal threshold
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1000e18; // 1,000 Mine

    /// @notice The maximum setable proposal threshold
    uint256 public constant MAX_PROPOSAL_THRESHOLD = 100000e18; //100,000 Mine

    /// @notice The minimum setable voting period
    uint256 public constant MIN_VOTING_PERIOD = 5760; // About 24 hours

    /// @notice The max setable voting period
    uint256 public constant MAX_VOTING_PERIOD = 80640; // About 2 weeks

    /// @notice The min setable voting delay
    uint256 public constant MIN_VOTING_DELAY = 1;

    /// @notice The max setable voting delay
    uint256 public constant MAX_VOTING_DELAY = 40320; // About 1 week

    /// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    uint256 public constant quorumVotes = 400000e18; // 400,000 = 4% of Mine

    /// @notice The maximum number of actions that can be included in a proposal
    uint256 public constant proposalMaxOperations = 10; // 10 actions

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256('EIP712Domain(string name,uint256 chainId,address verifyingContract)');

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256('Ballot(uint256 proposalId,uint8 support)');

    /// @notice The address of the Mine token
    IVotes public immutable mineToken;

    /**
     * ================ STATE VARIABLES ================
     */

    /**
     * IMPORTANT:
     * !STORAGE COLLISION WARNING!
     * Adding, removing or rearranging undermentioned state variables can result in a storage collision after a contract
     * upgrade. Any new state variables must be added beneath these to prevent storage conflicts.
     */

    /// @notice The delay before voting on a proposal may take place, once proposed, in blocks
    uint256 public votingDelay;

    /// @notice The duration of voting on a proposal, in blocks
    uint256 public votingPeriod;

    /// @notice The number of votes required in order for a voter to become a proposer
    uint256 public proposalThreshold;

    /// @notice The total number of proposals
    uint256 public proposalCount;

    /// @notice The address of the Mine Governance Protocol Timelock
    ITimelock public timelock;

    /// @notice The official record of all proposals ever proposed
    mapping(uint256 => Proposal) public proposals;

    /// @notice The latest proposal for each proposer
    mapping(address => uint256) public latestProposalIds;

    /// @notice Stores the expiration of account whitelist status as a timestamp
    mapping(address => uint256) public whitelistAccountExpirations;

    /// @notice Address which manages whitelisted proposals and whitelist accounts
    address public whitelistGuardian;

    /**
     * IMPORTANT:
     * !STORAGE COLLISION WARNING!
     * Adding, removing or rearranging above state variables can result in a storage collision after a contract upgrade.
     * Any new state variables must be added beneath these to prevent storage conflicts.
     */

    /**
     * ================ CONSTRUCTOR ================
     */

    /**
     * @notice This contract employs a proxy pattern, so the main purpose of the constructor is to render the
     * implementation contract unusable. It initializes certain immutables to optimize gas usage when accessing these
     * variables. Primarily, it calls `super.initialize()` to ensure the contract cannot be initialized with valid
     * values for the remaining variables.
     * @param _mineToken The address of the Mine token
     */
    constructor(address _mineToken) {
        mineToken = IVotes(_mineToken);

        super.initialize();
    }

    /**
     * ================ EXTERNAL & PUBLIC FUNCTIONS ================
     */

    /**
     * @inheritdoc IGovernance
     */
    function initialize(
        address _timelock,
        uint256 _votingPeriod,
        uint256 _votingDelay,
        uint256 _proposalThreshold
    ) external override {
        if (_votingPeriod < MIN_VOTING_PERIOD || _votingPeriod > MAX_VOTING_PERIOD) {
            revert GovernanceInvalidVotingPeriod();
        }
        if (_votingDelay < MIN_VOTING_DELAY || _votingDelay > MAX_VOTING_DELAY) {
            revert GovernanceInvalidVotingDelay();
        }
        if (_proposalThreshold < MIN_PROPOSAL_THRESHOLD || _proposalThreshold > MAX_PROPOSAL_THRESHOLD) {
            revert GovernanceInvalidProposalThreshold();
        }
        timelock = ITimelock(_timelock);
        votingPeriod = _votingPeriod;
        votingDelay = _votingDelay;
        proposalThreshold = _proposalThreshold;
        _setOwner(msg.sender);

        super.initialize();
    }

    /**
     * @notice Admin function for setting the voting delay
     * @param newVotingDelay new voting delay, in blocks
     */
    function setVotingDelay(uint256 newVotingDelay) external onlyOwner {
        if (newVotingDelay < MIN_VOTING_DELAY || newVotingDelay > MAX_VOTING_DELAY) {
            revert GovernanceInvalidVotingDelay();
        }
        uint256 oldVotingDelay = votingDelay;
        votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay, votingDelay);
    }

    /**
     * @notice Admin function for setting the voting period
     * @param newVotingPeriod new voting period, in blocks
     */
    function setVotingPeriod(uint256 newVotingPeriod) external onlyOwner {
        if (newVotingPeriod < MIN_VOTING_PERIOD || newVotingPeriod > MAX_VOTING_PERIOD) {
            revert GovernanceInvalidVotingPeriod();
        }
        uint256 oldVotingPeriod = votingPeriod;
        votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
    }

    /**
     * @notice Admin function for setting the proposal threshold
     * @dev newProposalThreshold must be greater than the hardcoded min
     * @param newProposalThreshold new proposal threshold
     */
    function setProposalThreshold(uint256 newProposalThreshold) external onlyOwner {
        if (newProposalThreshold < MIN_PROPOSAL_THRESHOLD || newProposalThreshold > MAX_PROPOSAL_THRESHOLD) {
            revert GovernanceInvalidProposalThreshold();
        }
        uint256 oldProposalThreshold = proposalThreshold;
        proposalThreshold = newProposalThreshold;

        emit ProposalThresholdSet(oldProposalThreshold, proposalThreshold);
    }

    /**
     * @notice Admin function for setting the whitelist expiration as a timestamp for an account. Whitelist status allows accounts to propose without meeting threshold
     * @dev Cannot use `onlyOwner` modifier, since this function can also be called by the `whitelistGuardian`.
     * @param account Account address to set whitelist expiration for
     * @param expiration Expiration for account whitelist status as timestamp (if now < expiration, whitelisted)
     */
    function setWhitelistAccountExpiration(address account, uint256 expiration) external {
        if (msg.sender != owner && msg.sender != whitelistGuardian) {
            revert GovernanceUnauthorizedSender(msg.sender);
        }
        whitelistAccountExpirations[account] = expiration;

        emit WhitelistAccountExpirationSet(account, expiration);
    }

    /**
     * @notice Admin function for setting the whitelistGuardian. WhitelistGuardian can cancel proposals from whitelisted addresses
     * @param account Account to set whitelistGuardian to (0x0 to remove whitelistGuardian)
     */
    function setWhitelistGuardian(address account) external onlyOwner {
        address oldGuardian = whitelistGuardian;
        whitelistGuardian = account;

        emit WhitelistGuardianSet(oldGuardian, whitelistGuardian);
    }

    /**
     * @inheritdoc IGovernance
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        // Reject proposals before initiating as Governor
        require(address(timelock) != address(0), 'Governance::propose: Governance not active');
        // Allow addresses above proposal threshold and whitelisted addresses to propose
        if (
            mineToken.getPriorVotes(msg.sender, (block.number - 1)) <= proposalThreshold && !isWhitelisted(msg.sender)
        ) {
            revert GovernanceVotesBelowProposalThreshold();
        }
        if (
            targets.length != values.length || targets.length != signatures.length || targets.length != calldatas.length
        ) {
            revert GovernanceArityMismatch();
        }
        if (targets.length == 0) {
            revert GovernanceNoActions();
        }
        if (targets.length > proposalMaxOperations) {
            revert GovernanceTooManyActions();
        }

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = getState(latestProposalId);
            if (proposersLatestProposalState == ProposalState.Active) {
                revert GovernanceOnlyOneActiveProposalAllowed();
            }
            if (proposersLatestProposalState == ProposalState.Pending) {
                revert GovernanceOnlyOnePendingProposalAllowed();
            }
        }

        uint256 startBlock = block.number + votingDelay;
        uint256 endBlock = startBlock + votingPeriod;

        uint256 newProposalID = ++proposalCount;
        Proposal storage newProposal = proposals[newProposalID];

        // This should never happen but add a check in case.
        require(newProposal.id == 0, 'Governance::propose: ProposalID collsion'); // TODO: is this really necessary?

        newProposal.id = newProposalID;
        newProposal.proposer = msg.sender;
        newProposal.eta = 0;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.signatures = signatures;
        newProposal.calldatas = calldatas;
        newProposal.startBlock = startBlock;
        newProposal.endBlock = endBlock;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.abstainVotes = 0;
        newProposal.canceled = false;
        newProposal.executed = false;

        latestProposalIds[newProposal.proposer] = newProposal.id;

        emit ProposalCreated(
            newProposal.id,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            startBlock,
            endBlock,
            description
        );
        return newProposal.id;
    }

    /**
     * @inheritdoc IGovernance
     */
    function queue(uint256 proposalId) external {
        if (getState(proposalId) != ProposalState.Succeeded) {
            revert GovernanceInvalidProposalState(ProposalState.Succeeded, getState(proposalId));
        }
        Proposal storage proposal = proposals[proposalId];
        uint256 eta = block.timestamp + timelock.delay();
        for (uint256 i; i < proposal.targets.length; ) {
            _queueOrRevert(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], eta);

            unchecked {
                ++i;
            }
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    /**
     * @inheritdoc IGovernance
     */
    function execute(uint256 proposalId) external payable {
        if (getState(proposalId) != ProposalState.Queued) {
            revert GovernanceInvalidProposalState(ProposalState.Queued, getState(proposalId));
        }
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction{ value: proposal.values[i] }(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }
        emit ProposalExecuted(proposalId);
    }

    /**
     * @inheritdoc IGovernance
     */
    function cancel(uint256 proposalId) external {
        if (getState(proposalId) == ProposalState.Executed) {
            revert GovernanceProposalAlreadyExecuted();
        }

        Proposal storage proposal = proposals[proposalId];
        address proposer = proposal.proposer;
        // Proposer can cancel
        if (msg.sender != proposer) {
            if (mineToken.getPriorVotes(proposer, block.number - 1) >= proposalThreshold) {
                revert GovernanceVotesAboveProposalThreshold();
            }

            // Whitelisted proposers can't be canceled for falling below proposal threshold except whitelist guardian
            if (isWhitelisted(proposer) && msg.sender != whitelistGuardian) {
                revert GovernanceUnauthorizedCanceler();
            }
        }

        proposal.canceled = true;
        for (uint256 i; i < proposal.targets.length; ++i) {
            timelock.cancelTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }

        emit ProposalCanceled(proposalId);
    }

    /**
     * @inheritdoc IGovernance
     */
    function castVote(uint256 proposalId, uint8 support) external {
        emit VoteCast(msg.sender, proposalId, support, _castVote(msg.sender, proposalId, support), '');
    }

    /**
     * @inheritdoc IGovernance
     */
    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external {
        emit VoteCast(msg.sender, proposalId, support, _castVote(msg.sender, proposalId, support), reason);
    }

    /**
     * @inheritdoc IGovernance
     */
    function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), _getChainId(), address(this))
        );
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        if (signatory == address(0)) {
            revert GovernanceInvalidDelegateSignature();
        }
        emit VoteCast(signatory, proposalId, support, _castVote(signatory, proposalId, support), '');
    }

    /**
     * @notice View function which returns if an account is whitelisted
     * @param account Account to check white list status of
     * @return If the account is whitelisted
     */
    function isWhitelisted(address account) public view returns (bool) {
        return (whitelistAccountExpirations[account] > block.timestamp);
    }

    /**
     * @notice Gets actions of a proposal
     * @param proposalId the id of the proposal
     * @return targets of the proposal actions
     * @return values of the proposal actions
     * @return signatures of the proposal actions
     * @return calldatas of the proposal actions
     */
    function getActions(
        uint256 proposalId
    )
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        )
    {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    /**
     * @notice Gets the receipt for a voter on a given proposal
     * @param proposalId the id of proposal
     * @param voter The address of the voter
     * @return The voting receipt
     */
    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    /**
     * @notice Gets the state of a proposal
     * @param proposalId The id of the proposal
     * @return Proposal state
     */
    function getState(uint256 proposalId) public view returns (ProposalState) {
        if (proposalId == 0 || proposalId > proposalCount) {
            revert GovernanceInvalidProposalId();
        }
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta + timelock.GRACE_PERIOD()) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    /**
     * ================ INTERNAL & PRIVATE FUNCTIONS ================
     */

    function _queueOrRevert(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        if (timelock.queuedTransactions(keccak256(abi.encode(target, value, signature, data, eta)))) {
            revert GovernanceDuplicatedProposal();
        }
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    /**
     * @notice Internal function that caries out voting logic
     * @param voter The voter that is casting their vote
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @return The number of votes cast
     */
    function _castVote(address voter, uint256 proposalId, uint8 support) internal returns (uint96) {
        if (getState(proposalId) != ProposalState.Active) {
            revert GovernanceVotingClosed();
        }
        if (support > 2) {
            revert GovernanceInvalidVoteType();
        }
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        if (receipt.hasVoted == true) {
            revert GovernanceVoterAlreadyVoted();
        }
        uint96 votes = mineToken.getPriorVotes(voter, proposal.startBlock);

        if (support == 0) {
            proposal.againstVotes = proposal.againstVotes + votes;
        } else if (support == 1) {
            proposal.forVotes = proposal.forVotes + votes;
        } else if (support == 2) {
            proposal.abstainVotes = proposal.abstainVotes + votes;
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        return votes;
    }

    function _getChainId() internal view returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }
}
