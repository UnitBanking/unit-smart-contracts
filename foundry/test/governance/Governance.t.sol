// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { GovernanceTestBase } from './GovernanceTestBase.t.sol';
import { IGovernance } from '../../../contracts/interfaces/IGovernance.sol';
import { IProxiable } from '../../../contracts/interfaces/IProxiable.sol';
import { Ownable } from '../../../contracts/abstracts/Ownable.sol';
import 'forge-std/console.sol';

contract GovernanceHarnessTest is GovernanceTestBase {
    /**
     * ================ constants ================
     */
    function test_constants_HaveCorrectValues() public {
        // Arrange & Act
        string memory name = governanceProxy.name();
        uint256 minProposalThreshold = governanceProxy.MIN_PROPOSAL_THRESHOLD();
        uint256 maxProposalThreshold = governanceProxy.MAX_PROPOSAL_THRESHOLD();
        uint256 minVotingPeriod = governanceProxy.MIN_VOTING_PERIOD();
        uint256 maxVotingPeriod = governanceProxy.MAX_VOTING_PERIOD();
        uint256 minVotingDelay = governanceProxy.MIN_VOTING_DELAY();
        uint256 maxVotingDelay = governanceProxy.MAX_VOTING_DELAY();
        uint256 quorumVotes = governanceProxy.quorumVotes();
        uint256 proposalMaxOperations = governanceProxy.proposalMaxOperations();

        // Assert
        assertEq(name, 'Mine Governance');
        assertEq(minProposalThreshold, 1000e18);
        assertEq(maxProposalThreshold, 100000e18);
        assertEq(minVotingPeriod, 5760);
        assertEq(maxVotingPeriod, 80640);
        assertEq(minVotingDelay, 1);
        assertEq(maxVotingDelay, 40320);
        assertEq(quorumVotes, 400000e18);
        assertEq(proposalMaxOperations, 10);
    }

    /**
     * ================ constructor() ================
     */
    function test_constructor_SuccessfullySetsValues() public {
        // Arrange & Act
        address mineTokenAddress = address(governanceImplementation.mineToken());
        bool initialized = governanceImplementation.initialized();

        // Assert
        assertEq(mineTokenAddress, address(mineToken));
        assertEq(initialized, true);
    }

    /**
     * ================ initialize() ================
     */

    function test_initialize_RevertsWhenInitializingImplementation() public {
        // Arrange & Act & Assert
        vm.expectRevert(IProxiable.ProxiableAlreadyInitialized.selector);
        governanceImplementation.initialize();
    }

    function test_initialize_RevertsWhenInitializingTwice() public {
        // Arrange & Act & Assert
        vm.expectRevert(IProxiable.ProxiableAlreadyInitialized.selector);
        governanceProxy.initialize();
    }

    function test_initialize_SuccessfullyInitializes() public {
        // Arrange & Act
        uint256 votingDelay = governanceProxy.votingDelay();
        uint256 votingPeriod = governanceProxy.votingPeriod();
        uint256 proposalThreshold = governanceProxy.proposalThreshold();
        address owner = governanceProxy.owner();
        bool initialized = governanceProxy.initialized();
        address timelock = address(governanceProxy.timelock());

        // Assert
        assertEq(votingDelay, INITIAL_VOTING_DELAY);
        assertEq(votingPeriod, INITIAL_VOTING_PERIOD);
        assertEq(proposalThreshold, INITIAL_PROPOSAL_THRESHOLD);
        assertEq(owner, address(this));
        assertEq(initialized, true);
        assertNotEq(timelock, address(0));
    }

    /**
     * ================ setVotingDelay() ================
     */

    function test_setVotingDelay_SuccessfullySetsNewVotingDelay() public {
        // Arrange
        uint256 newVotingDelay = 4;
        uint256 oldVotingDelay = governanceProxy.votingDelay();

        // Act
        vm.expectEmit();
        emit IGovernance.VotingDelaySet(oldVotingDelay, newVotingDelay);
        governanceProxy.setVotingDelay(newVotingDelay);

        // Assert
        uint256 votingDelay = governanceProxy.votingDelay();
        assertEq(votingDelay, newVotingDelay);
        assertNotEq(votingDelay, oldVotingDelay);
    }

    function test_setVotingDelay_RevertsWhenSettingValueOutOfBounds() public {
        // Arrange
        uint256 minVotingDelay = governanceProxy.MIN_VOTING_DELAY();
        uint256 maxVotingDelay = governanceProxy.MAX_VOTING_DELAY();

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceInvalidVotingDelay.selector);
        governanceProxy.setVotingDelay(minVotingDelay - 1);
        vm.expectRevert(IGovernance.GovernanceInvalidVotingDelay.selector);
        governanceProxy.setVotingDelay(maxVotingDelay + 1);
    }

    /**
     * ================ setVotingPeriod() ================
     */

    function test_setVotingPeriod_SuccessfullySetsNewVotingPeriod() public {
        // Arrange
        uint256 newVotingPeriod = 5790;
        uint256 oldVotingPeriod = governanceProxy.votingPeriod();

        // Act
        vm.expectEmit();
        emit IGovernance.VotingPeriodSet(oldVotingPeriod, newVotingPeriod);
        governanceProxy.setVotingPeriod(newVotingPeriod);

        // Assert
        uint256 votingPeriod = governanceProxy.votingPeriod();
        assertEq(votingPeriod, newVotingPeriod);
        assertNotEq(votingPeriod, oldVotingPeriod);
    }

    function test_setVotingPeriod_RevertsWhenSettingValueOutOfBounds() public {
        // Arrange
        uint256 minVotingPeriod = governanceProxy.MIN_VOTING_PERIOD();
        uint256 maxVotingPeriod = governanceProxy.MAX_VOTING_PERIOD();

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceInvalidVotingPeriod.selector);
        governanceProxy.setVotingPeriod(minVotingPeriod - 1);
        vm.expectRevert(IGovernance.GovernanceInvalidVotingPeriod.selector);
        governanceProxy.setVotingPeriod(maxVotingPeriod + 1);
    }

    /**
     * ================ setProposalThreshold() ================
     */

    function test_setProposalThreshold_SuccessfullySetsNewVotingPeriod() public {
        // Arrange
        uint256 newProposalThreshold = 3000e18;
        uint256 oldProposalThreshold = governanceProxy.proposalThreshold();

        // Act
        vm.expectEmit();
        emit IGovernance.ProposalThresholdSet(oldProposalThreshold, newProposalThreshold);
        governanceProxy.setProposalThreshold(newProposalThreshold);

        // Assert
        uint256 proposalThreshold = governanceProxy.proposalThreshold();
        assertEq(proposalThreshold, newProposalThreshold);
        assertNotEq(proposalThreshold, oldProposalThreshold);
    }

    function test_setProposalThreshold_RevertsWhenSettingValueOutOfBounds() public {
        // Arrange
        uint256 minProposalThreshold = governanceProxy.MIN_PROPOSAL_THRESHOLD();
        uint256 maxProposalThreshold = governanceProxy.MAX_PROPOSAL_THRESHOLD();

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceInvalidProposalThreshold.selector);
        governanceProxy.setProposalThreshold(minProposalThreshold - 1);
        vm.expectRevert(IGovernance.GovernanceInvalidProposalThreshold.selector);
        governanceProxy.setProposalThreshold(maxProposalThreshold + 1);
    }

    /**
     * ================ setWhitelistGuardian() ================
     */

    function test_setWhitelistGuardian_RevertsWhenCalledByUnauthorizedOwner() public {
        // Arrange & Act & Assert
        vm.startPrank(wallet);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedOwner.selector, wallet));
        governanceProxy.setWhitelistGuardian(wallet);
    }

    function test_setWhitelistGuardian_SuccessfullySetsWhitelistGuardian() public {
        // Arrange
        address oldWhitelistGuardian = governanceProxy.whitelistGuardian();
        address newWhitelistGuardian = wallet;

        // Act
        governanceProxy.setWhitelistGuardian(newWhitelistGuardian);

        // Assert
        address whitelistGuardian = governanceProxy.whitelistGuardian();
        assertEq(whitelistGuardian, newWhitelistGuardian);
        assertNotEq(whitelistGuardian, oldWhitelistGuardian);
    }

    function test_setWhitelistGuardian_SuccessfullySetsWhitelistGuardianToZeroAddress() public {
        // Arrange
        address newWhitelistGuardian = address(0);

        // Act
        governanceProxy.setWhitelistGuardian(newWhitelistGuardian);

        // Assert
        address whitelistGuardian = governanceProxy.whitelistGuardian();
        assertEq(whitelistGuardian, newWhitelistGuardian);
    }

    /**
     * ================ setWhitelistAccountExpiration() ================
     */

    function test_setWhitelistAccountExpiration_RevertsWhenSettingByUnauthorizedAdmin() public {
        // Arrange & Act & Assert
        vm.prank(wallet);
        vm.expectRevert(abi.encodeWithSelector(IGovernance.GovernanceUnauthorizedSender.selector, wallet));
        governanceProxy.setWhitelistAccountExpiration(wallet, 10);
    }

    function test_setWhitelistAccountExpiration_SuccessfullySetsByOwner() public {
        // Arrange
        address user = vm.addr(100);

        // Act
        bool isWhitelistedBefore = governanceProxy.isWhitelisted(user);
        assertEq(isWhitelistedBefore, false);
        governanceProxy.setWhitelistAccountExpiration(user, block.timestamp + 10);

        // Assert
        bool isWhitelistedAfter = governanceProxy.isWhitelisted(user);
        assertEq(isWhitelistedAfter, true);
    }

    function test_setWhitelistAccountExpiration_SuccessfullySetsByWhitelistGuardian() public {
        // Arrange
        address user = vm.addr(100);
        governanceProxy.setWhitelistGuardian(wallet);

        // Act
        bool isWhitelistedBefore = governanceProxy.isWhitelisted(user);
        assertEq(isWhitelistedBefore, false);
        vm.prank(wallet);
        governanceProxy.setWhitelistAccountExpiration(user, block.timestamp + 10);

        // Assert
        bool isWhitelistedAfter = governanceProxy.isWhitelisted(user);
        assertEq(isWhitelistedAfter, true);
    }

    /**
     * ================ isWhitelisted() ================
     */

    function test_isWhitelisted_SuccessfullyReturnsValue() public {
        // Arrange
        address user = vm.addr(100);
        uint256 expiration = block.timestamp + 10;
        uint256 timestampBeforeExpiration = expiration - 1;

        // Act & Assert
        assertEq(governanceProxy.isWhitelisted(user), false);
        governanceProxy.setWhitelistAccountExpiration(user, expiration);
        assertEq(governanceProxy.isWhitelisted(user), true);

        vm.warp(timestampBeforeExpiration);
        assertEq(governanceProxy.isWhitelisted(user), true);
        vm.warp(expiration);
        assertEq(governanceProxy.isWhitelisted(user), false);
    }

    /**
     * ================ getReceipt() ================
     */

    function test_getReceipt_SuccessfullyReturnsValue() public {
        // Arrange
        uint256 quorumVotes = governanceProxy.quorumVotes();
        address user = _createUserAndMintMineToken(quorumVotes + 1);
        vm.prank(user);
        mineToken.delegate(user);
        governanceProxy.setWhitelistAccountExpiration(user, block.timestamp + 10_000);
        uint256 proposalId = _propose(user);
        _voteAndRollToEndBlock(proposalId, user);

        // Act
        IGovernance.Receipt memory receipt = governanceProxy.getReceipt(proposalId, user);
        IGovernance.Receipt memory nonVoterReceipt = governanceProxy.getReceipt(proposalId, wallet);

        // Assert
        assertEq(receipt.hasVoted, true);
        assertEq(receipt.support, 1);
        assertEq(receipt.votes, mineToken.balanceOf(user));

        assertEq(nonVoterReceipt.hasVoted, false);
        assertEq(nonVoterReceipt.support, 0);
        assertEq(nonVoterReceipt.votes, 0);
    }

    /**
     * ================ getActions() ================
     */

    function test_getActions_SuccessfullyReturnsValue() public {
        // Arrange
        uint256 quorumVotes = governanceProxy.quorumVotes();
        address user = _createUserAndMintMineToken(quorumVotes + 1);
        vm.prank(user);
        mineToken.delegate(user);
        governanceProxy.setWhitelistAccountExpiration(user, block.timestamp + 10_000);
        uint256 proposalId = _propose(user);
        _voteAndRollToEndBlock(proposalId, user);

        address[] memory expectedTargets = new address[](1);
        expectedTargets[0] = address(mineToken);
        uint256[] memory expectedValues = new uint256[](1);
        expectedValues[0] = 0;
        string[] memory expectedSignatures = new string[](1);
        expectedSignatures[0] = 'transfer(address,uint256)';
        bytes[] memory expectedCalldatas = new bytes[](1);
        expectedCalldatas[0] = abi.encode(user, 1e18);

        // Act
        (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        ) = governanceProxy.getActions(proposalId);
        (
            address[] memory nonProposalTargets,
            uint256[] memory nonProposalValues,
            string[] memory nonProposalSignatures,
            bytes[] memory nonProposalCalldatas
        ) = governanceProxy.getActions(governanceProxy.proposalCount() + 1);

        // Assert
        assertEq(targets.length, 1);
        assertEq(values.length, 1);
        assertEq(signatures.length, 1);
        assertEq(calldatas.length, 1);
        assertEq(targets[0], expectedTargets[0]);
        assertEq(values[0], expectedValues[0]);
        assertEq(signatures[0], expectedSignatures[0]);
        assertEq(calldatas[0], expectedCalldatas[0]);

        assertEq(nonProposalTargets.length, 0);
        assertEq(nonProposalValues.length, 0);
        assertEq(nonProposalSignatures.length, 0);
        assertEq(nonProposalCalldatas.length, 0);
    }
}
