// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import './interfaces/IGovernance.sol';
import './interfaces/IProxiable.sol';
import './interfaces/ITimelock.sol';
import './interfaces/IVote.sol';
import './abstracts/Ownable.sol';
import './Timelock.sol';

contract Governance is IGovernance, IProxiable, Ownable {
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

    /// @notice The address of the Mine token
    IVotes public mineToken;

    /// @notice The official record of all proposals ever proposed
    mapping(uint256 => Proposal) public proposals;

    /// @notice The latest proposal for each proposer
    mapping(address => uint) public latestProposalIds;

    /// @notice Stores the expiration of account whitelist status as a timestamp
    mapping(address => uint) public whitelistAccountExpirations;

    /// @notice Address which manages whitelisted proposals and whitelist accounts
    address public whitelistGuardian;

    function initialize() public override {
        _setOwner(msg.sender);
    }

    /**
     * @notice Initiate the Gavornance contract
     * @dev Owner only. Sets initial proposal id which initiates the contract, ensuring a continuous proposal id count
     * @param _mineToken The address of the Mine token
     * @param _votingPeriod The initial voting period
     * @param _votingDelay The initial voting delay
     * @param _proposalThreshold The initial proposal threshold
     */
    function initiate(
        address _mineToken,
        uint256 _votingPeriod,
        uint256 _votingDelay,
        uint256 _proposalThreshold,
        uint256 _timelockDelay
    ) external override onlyOwner {
        require(address(timelock) == address(0), 'Governance::initiate: can only initiate once');
        require(msg.sender == owner, 'Governance::initiate: owner only');
        require(_mineToken != address(0), 'Governance::initiate: invalid mine token address');
        require(
            _votingPeriod >= MIN_VOTING_PERIOD && _votingPeriod <= MAX_VOTING_PERIOD,
            'Governance::initiate: invalid voting period'
        );
        require(
            _votingDelay >= MIN_VOTING_DELAY && _votingDelay <= MAX_VOTING_DELAY,
            'Governance::initiate: invalid voting delay'
        );
        require(
            _proposalThreshold >= MIN_PROPOSAL_THRESHOLD && _proposalThreshold <= MAX_PROPOSAL_THRESHOLD,
            'Governance::initiate: invalid proposal threshold'
        );
        address _timelock = address(new Timelock(_timelockDelay));
        timelock = ITimelock(_timelock);
        mineToken = IVotes(_mineToken);
        votingPeriod = _votingPeriod;
        votingDelay = _votingDelay;
        proposalThreshold = _proposalThreshold;
        _setOwner(_timelock);
    }

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
        uint[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint) {
        // Reject proposals before initiating as Governor
        require(address(timelock) != address(0), 'Governance::propose: Governance not active');
        // Allow addresses above proposal threshold and whitelisted addresses to propose
        require(
            mineToken.getPriorVotes(msg.sender, (block.number - 1)) > proposalThreshold || isWhitelisted(msg.sender),
            'Governance::propose: proposer votes below proposal threshold'
        );
        require(
            targets.length == values.length &&
                targets.length == signatures.length &&
                targets.length == calldatas.length,
            'Governance::propose: proposal function information arity mismatch'
        );
        require(targets.length != 0, 'Governance::propose: must provide actions');
        require(targets.length <= proposalMaxOperations, 'Governance::propose: too many actions');

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(latestProposalId);
            require(
                proposersLatestProposalState != ProposalState.Active,
                'Governance::propose: one live proposal per proposer, found an already active proposal'
            );
            require(
                proposersLatestProposalState != ProposalState.Pending,
                'Governance::propose: one live proposal per proposer, found an already pending proposal'
            );
        }

        uint256 startBlock = block.number + votingDelay;
        uint256 endBlock = startBlock + votingPeriod;

        uint256 newProposalID = ++proposalCount;
        Proposal storage newProposal = proposals[newProposalID];

        // This should never happen but add a check in case.
        require(newProposal.id == 0, 'Governance::propose: ProposalID collsion');

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
     * @notice Queues a proposal of state succeeded
     * @param proposalId The id of the proposal to queue
     */
    function queue(uint256 proposalId) external {
        require(
            state(proposalId) == ProposalState.Succeeded,
            'Governance::queue: proposal can only be queued if it is succeeded'
        );
        Proposal storage proposal = proposals[proposalId];
        uint256 eta = block.timestamp + timelock.delay();
        for (uint256 i; i < proposal.targets.length; ) {
            queueOrRevertInternal(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                eta
            );

            unchecked {
                ++i;
            }
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    function queueOrRevertInternal(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        require(
            !timelock.queuedTransactions(keccak256(abi.encode(target, value, signature, data, eta))),
            'Governance::queueOrRevertInternal: identical proposal action already queued at eta'
        );
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    /**
     * @notice Executes a queued proposal if eta has passed
     * @param proposalId The id of the proposal to execute
     */
    function execute(uint256 proposalId) external payable {
        require(
            state(proposalId) == ProposalState.Queued,
            'Governance::execute: proposal can only be executed if it is queued'
        );
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
     * @notice Cancels a proposal only if sender is the proposer, or proposer delegates dropped below proposal threshold
     * @param proposalId The id of the proposal to cancel
     */
    function cancel(uint256 proposalId) external {
        require(state(proposalId) != ProposalState.Executed, 'Governance::cancel: cannot cancel executed proposal');

        Proposal storage proposal = proposals[proposalId];

        // Proposer can cancel
        if (msg.sender != proposal.proposer) {
            // Whitelisted proposers can't be canceled for falling below proposal threshold
            if (isWhitelisted(proposal.proposer)) {
                require(
                    (mineToken.getPriorVotes(proposal.proposer, block.number - 1) < proposalThreshold) &&
                        msg.sender == whitelistGuardian,
                    'Governance::cancel: whitelisted proposer'
                );
            } else {
                require(
                    (mineToken.getPriorVotes(proposal.proposer, block.number - 1) < proposalThreshold),
                    'Governance::cancel: proposer above threshold'
                );
            }
        }

        proposal.canceled = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
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
        returns (address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas)
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
    function state(uint256 proposalId) public view returns (ProposalState) {
        require(proposalId > 0 && proposalId <= proposalCount, 'Governance::state: invalid proposal id');
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
     * @notice Cast a vote for a proposal
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     */
    function castVote(uint256 proposalId, uint8 support) external {
        emit VoteCast(msg.sender, proposalId, support, castVoteInternal(msg.sender, proposalId, support), '');
    }

    /**
     * @notice Cast a vote for a proposal with a reason
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @param reason The reason given for the vote by the voter
     */
    function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external {
        emit VoteCast(msg.sender, proposalId, support, castVoteInternal(msg.sender, proposalId, support), reason);
    }

    /**
     * @notice Cast a vote for a proposal by signature
     * @dev External function that accepts EIP-712 signatures for voting on proposals.
     */
    function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainIdInternal(), address(this))
        );
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), 'Governance::castVoteBySig: invalid signature');
        emit VoteCast(signatory, proposalId, support, castVoteInternal(signatory, proposalId, support), '');
    }

    /**
     * @notice Internal function that caries out voting logic
     * @param voter The voter that is casting their vote
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @return The number of votes cast
     */
    function castVoteInternal(address voter, uint256 proposalId, uint8 support) internal returns (uint96) {
        require(state(proposalId) == ProposalState.Active, 'Governance::castVoteInternal: voting is closed');
        require(support <= 2, 'Governance::castVoteInternal: invalid vote type');
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(receipt.hasVoted == false, 'Governance::castVoteInternal: voter already voted');
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

    /**
     * @notice View function which returns if an account is whitelisted
     * @param account Account to check white list status of
     * @return If the account is whitelisted
     */
    function isWhitelisted(address account) public view returns (bool) {
        return (whitelistAccountExpirations[account] > block.timestamp);
    }

    /**
     * @notice Admin function for setting the voting delay
     * @param newVotingDelay new voting delay, in blocks
     */
    function _setVotingDelay(uint256 newVotingDelay) external {
        require(msg.sender == owner, 'Governance::_setVotingDelay: owner only');
        require(
            newVotingDelay >= MIN_VOTING_DELAY && newVotingDelay <= MAX_VOTING_DELAY,
            'Governance::_setVotingDelay: invalid voting delay'
        );
        uint256 oldVotingDelay = votingDelay;
        votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay, votingDelay);
    }

    /**
     * @notice Admin function for setting the voting period
     * @param newVotingPeriod new voting period, in blocks
     */
    function _setVotingPeriod(uint256 newVotingPeriod) external {
        require(msg.sender == owner, 'Governance::_setVotingPeriod: owner only');
        require(
            newVotingPeriod >= MIN_VOTING_PERIOD && newVotingPeriod <= MAX_VOTING_PERIOD,
            'Governance::_setVotingPeriod: invalid voting period'
        );
        uint256 oldVotingPeriod = votingPeriod;
        votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
    }

    /**
     * @notice Admin function for setting the proposal threshold
     * @dev newProposalThreshold must be greater than the hardcoded min
     * @param newProposalThreshold new proposal threshold
     */
    function _setProposalThreshold(uint256 newProposalThreshold) external {
        require(msg.sender == owner, 'Governance::_setProposalThreshold: owner only');
        require(
            newProposalThreshold >= MIN_PROPOSAL_THRESHOLD && newProposalThreshold <= MAX_PROPOSAL_THRESHOLD,
            'Governance::_setProposalThreshold: invalid proposal threshold'
        );
        uint256 oldProposalThreshold = proposalThreshold;
        proposalThreshold = newProposalThreshold;

        emit ProposalThresholdSet(oldProposalThreshold, proposalThreshold);
    }

    /**
     * @notice Admin function for setting the whitelist expiration as a timestamp for an account. Whitelist status allows accounts to propose without meeting threshold
     * @param account Account address to set whitelist expiration for
     * @param expiration Expiration for account whitelist status as timestamp (if now < expiration, whitelisted)
     */
    function _setWhitelistAccountExpiration(address account, uint256 expiration) external {
        require(
            msg.sender == owner || msg.sender == whitelistGuardian,
            'Governance::_setWhitelistAccountExpiration: owner only'
        );
        whitelistAccountExpirations[account] = expiration;

        emit WhitelistAccountExpirationSet(account, expiration);
    }

    /**
     * @notice Admin function for setting the whitelistGuardian. WhitelistGuardian can cancel proposals from whitelisted addresses
     * @param account Account to set whitelistGuardian to (0x0 to remove whitelistGuardian)
     */
    function _setWhitelistGuardian(address account) external {
        require(msg.sender == owner, 'Governance::_setWhitelistGuardian: owner only');
        address oldGuardian = whitelistGuardian;
        whitelistGuardian = account;

        emit WhitelistGuardianSet(oldGuardian, whitelistGuardian);
    }

    function getChainIdInternal() internal view returns (uint) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}
