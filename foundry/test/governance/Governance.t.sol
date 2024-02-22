// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { GovernanceTestBase } from './GovernanceTestBase.t.sol';
import { IGovernance } from '../../../contracts/interfaces/IGovernance.sol';
import { IProxiable } from '../../../contracts/interfaces/IProxiable.sol';
import { Ownable } from '../../../contracts/abstracts/Ownable.sol';
import { GovernanceHarness } from '../../../contracts/test/GovernanceHarness.sol';
import { Proxy } from '../../../contracts/Proxy.sol';

contract GovernanceHarnessTest is GovernanceTestBase {
    /**
     * ================ constants ================
     */
    function test_constants_HaveCorrectValues() public {
        // Arrange & Act
        string memory name = governanceProxy.name();
        uint256 minQuorumVotesPercentageNumerator = governanceProxy.MIN_QUORUM_VOTES_PERCENTAGE_NUMERATOR();
        uint256 maxQuorumVotesPercentageNumerator = governanceProxy.MAX_QUORUM_VOTES_PERCENTAGE_NUMERATOR();
        uint256 quorumVotesPercentageDenominator = governanceProxy.QUORUM_VOTES_PERCENTAGE_DENOMINATOR();
        uint256 minProposalThresholdPercentageNumerator = governanceProxy.MIN_PROPOSAL_THRESHOLD_PERCENTAGE_NUMERATOR();
        uint256 maxProposalThresholdPercentageNumerator = governanceProxy.MAX_PROPOSAL_THRESHOLD_PERCENTAGE_NUMERATOR();
        uint256 proposalThresholdPercentageDenominator = governanceProxy.PROPOSAL_THRESHOLD_PERCENTAGE_DENOMINATOR();
        uint256 minVotingPeriod = governanceProxy.MIN_VOTING_PERIOD();
        uint256 maxVotingPeriod = governanceProxy.MAX_VOTING_PERIOD();
        uint256 minVotingDelay = governanceProxy.MIN_VOTING_DELAY();
        uint256 maxVotingDelay = governanceProxy.MAX_VOTING_DELAY();
        uint256 proposalMaxOperations = governanceProxy.proposalMaxOperations();

        // Assert
        assertEq(name, 'Mine Governance');
        assertEq(minQuorumVotesPercentageNumerator, 1);
        assertEq(maxQuorumVotesPercentageNumerator, 10000);
        assertEq(quorumVotesPercentageDenominator, 10000);
        assertEq(minProposalThresholdPercentageNumerator, 1);
        assertEq(maxProposalThresholdPercentageNumerator, 10000);
        assertEq(proposalThresholdPercentageDenominator, 10000);
        assertEq(minVotingPeriod, 5760);
        assertEq(maxVotingPeriod, 80640);
        assertEq(minVotingDelay, 1);
        assertEq(maxVotingDelay, 40320);
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
        uint256 proposalThresholdPercentageNumerator = governanceProxy.proposalThresholdPercentageNumerator();
        uint256 quorumVotesPercentageNumerator = governanceProxy.quorumVotesPercentageNumerator();
        address owner = governanceProxy.owner();
        bool initialized = governanceProxy.initialized();
        address timelockAddress = address(governanceProxy.timelock());

        // Assert
        assertEq(votingDelay, INITIAL_VOTING_DELAY);
        assertEq(votingPeriod, INITIAL_VOTING_PERIOD);
        assertEq(quorumVotesPercentageNumerator, INITIAL_QUORUM_VOTES_PERCENTAGE_NUMBERATOR);
        assertEq(proposalThresholdPercentageNumerator, INITIAL_PROPOSAL_THRESHOLD_PERCENTAGE_NUMBERATOR);
        assertEq(owner, address(this));
        assertEq(initialized, true);
        assertNotEq(timelockAddress, address(0));
    }

    function test_initialize_RevertsWhenVotingPeriodOutOfBounds() public {
        // Arrange
        governanceImplementation = new GovernanceHarness(address(mineToken));
        governanceProxyType = new Proxy(address(this));
        uint256 votingPeriodTooShort = governanceImplementation.MIN_VOTING_PERIOD() - 1;
        uint256 votingPeriodTooLong = governanceImplementation.MAX_VOTING_PERIOD() + 1;

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceInvalidVotingPeriod.selector);
        governanceProxyType.upgradeToAndCall(
            address(governanceImplementation),
            abi.encodeWithSelector(
                IGovernance.initialize.selector,
                timelock,
                votingPeriodTooShort, // blocks
                2, // blocks
                2000,
                5100
            )
        );
        vm.expectRevert(IGovernance.GovernanceInvalidVotingPeriod.selector);
        governanceProxyType.upgradeToAndCall(
            address(governanceImplementation),
            abi.encodeWithSelector(
                IGovernance.initialize.selector,
                timelock,
                votingPeriodTooLong, // blocks
                2, // blocks
                2000,
                5100
            )
        );
    }

    function test_initialize_RevertsWhenVotingDelayOutOfBounds() public {
        // Arrange
        governanceImplementation = new GovernanceHarness(address(mineToken));
        governanceProxyType = new Proxy(address(this));
        uint256 votingDelayTooShort = governanceImplementation.MIN_VOTING_DELAY() - 1;
        uint256 votingDelayTooLong = governanceImplementation.MAX_VOTING_DELAY() + 1;

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceInvalidVotingDelay.selector);
        governanceProxyType.upgradeToAndCall(
            address(governanceImplementation),
            abi.encodeWithSelector(
                IGovernance.initialize.selector,
                timelock,
                5760, // blocks
                votingDelayTooShort, // blocks
                2000,
                5100
            )
        );
        vm.expectRevert(IGovernance.GovernanceInvalidVotingDelay.selector);
        governanceProxyType.upgradeToAndCall(
            address(governanceImplementation),
            abi.encodeWithSelector(
                IGovernance.initialize.selector,
                timelock,
                5760, // blocks
                votingDelayTooLong, // blocks
                2000,
                5100
            )
        );
    }

    function test_initialize_RevertsWhenQuorumVotesPercentageNumeratorOutOfBounds() public {
        // Arrange
        governanceImplementation = new GovernanceHarness(address(mineToken));
        governanceProxyType = new Proxy(address(this));
        uint256 quorumVotesPercentageNumeratorTooLow = governanceImplementation
            .MIN_QUORUM_VOTES_PERCENTAGE_NUMERATOR() - 1;
        uint256 quorumVotesPercentageNumeratorTooHigh = governanceImplementation
            .MAX_QUORUM_VOTES_PERCENTAGE_NUMERATOR() + 1;

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceInvalidQuorumVotesPercentageNumerator.selector);
        governanceProxyType.upgradeToAndCall(
            address(governanceImplementation),
            abi.encodeWithSelector(
                IGovernance.initialize.selector,
                timelock,
                5760, // blocks
                2, // blocks
                2000,
                quorumVotesPercentageNumeratorTooLow
            )
        );
        vm.expectRevert(IGovernance.GovernanceInvalidQuorumVotesPercentageNumerator.selector);
        governanceProxyType.upgradeToAndCall(
            address(governanceImplementation),
            abi.encodeWithSelector(
                IGovernance.initialize.selector,
                timelock,
                5760, // blocks
                2, // blocks
                2000,
                quorumVotesPercentageNumeratorTooHigh
            )
        );
    }

    function test_initialize_RevertsWhenProposalThresholdPercentageNumeratorOutOfBounds() public {
        // Arrange
        governanceImplementation = new GovernanceHarness(address(mineToken));
        governanceProxyType = new Proxy(address(this));
        uint256 proposalThresholdPercentageNumeratorTooLow = governanceImplementation
            .MIN_PROPOSAL_THRESHOLD_PERCENTAGE_NUMERATOR() - 1;
        uint256 proposalThresholdPercentageNumeratorTooHigh = governanceImplementation
            .MAX_PROPOSAL_THRESHOLD_PERCENTAGE_NUMERATOR() + 1;

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceInvalidProposalThresholdPercentageNumerator.selector);
        governanceProxyType.upgradeToAndCall(
            address(governanceImplementation),
            abi.encodeWithSelector(
                IGovernance.initialize.selector,
                timelock,
                5760, // blocks
                2, // blocks
                proposalThresholdPercentageNumeratorTooLow,
                5100
            )
        );
        vm.expectRevert(IGovernance.GovernanceInvalidProposalThresholdPercentageNumerator.selector);
        governanceProxyType.upgradeToAndCall(
            address(governanceImplementation),
            abi.encodeWithSelector(
                IGovernance.initialize.selector,
                timelock,
                5760, // blocks
                2, // blocks
                proposalThresholdPercentageNumeratorTooHigh,
                5100
            )
        );
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
     * ================ setQuorumVotesPercentageNumerator() ================
     */

    function test_setQuorumVotesPercentageNumerator_SuccessfullySetsValue() public {
        uint256 totalSupply1 = mineToken.totalSupply();
        uint256 quorumVotes1 = governanceProxy.getQuorumVotes();
        assertEq(
            quorumVotes1,
            (totalSupply1 * governanceProxy.quorumVotesPercentageNumerator()) /
                governanceProxy.QUORUM_VOTES_PERCENTAGE_DENOMINATOR()
        );

        governanceProxy.setQuorumVotesPercentageNumerator(6000); // 60%

        uint256 totalSupply2 = mineToken.totalSupply();
        uint256 quorumVotes2 = governanceProxy.getQuorumVotes();
        assertTrue(totalSupply1 == totalSupply2);
        assertTrue(quorumVotes1 != quorumVotes2);
        assertEq(
            quorumVotes2,
            (totalSupply2 * governanceProxy.quorumVotesPercentageNumerator()) /
                governanceProxy.QUORUM_VOTES_PERCENTAGE_DENOMINATOR()
        );
    }

    function test_setQuorumVotesPercentageNumerator_RevertsWhenSettingValueOutOfBounds() public {
        // Arrange
        uint256 minQuorumVotesPercentageNumerator = governanceProxy.MIN_QUORUM_VOTES_PERCENTAGE_NUMERATOR();
        uint256 maxQuorumVotesPercentageNumerator = governanceProxy.MAX_QUORUM_VOTES_PERCENTAGE_NUMERATOR();

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceInvalidQuorumVotesPercentageNumerator.selector);
        governanceProxy.setQuorumVotesPercentageNumerator(minQuorumVotesPercentageNumerator - 1);
        vm.expectRevert(IGovernance.GovernanceInvalidQuorumVotesPercentageNumerator.selector);
        governanceProxy.setQuorumVotesPercentageNumerator(maxQuorumVotesPercentageNumerator + 1);
    }

    /**
     * ================ setProposalThresholdPercentageNumerator() ================
     */

    function test_setProposalThresholdPercentageNumerator_SuccessfullySetsNewProposalThresholdPercentageNumerator()
        public
    {
        // Arrange
        uint256 newProposalThresholdPercentageNumerator = 3000; // 30%
        uint256 oldProposalThresholdPercentageNumerator = governanceProxy.proposalThresholdPercentageNumerator();

        // Act
        vm.expectEmit();
        emit IGovernance.ProposalThresholdPercentageNumeratorSet(
            oldProposalThresholdPercentageNumerator,
            newProposalThresholdPercentageNumerator
        );
        governanceProxy.setProposalThresholdPercentageNumerator(newProposalThresholdPercentageNumerator);

        // Assert
        uint256 proposalThresholdPercentageNumerator = governanceProxy.proposalThresholdPercentageNumerator();
        assertEq(proposalThresholdPercentageNumerator, newProposalThresholdPercentageNumerator);
        assertNotEq(proposalThresholdPercentageNumerator, oldProposalThresholdPercentageNumerator);
    }

    function test_setProposalThresholdPercentageNumerator_RevertsWhenSettingValueOutOfBounds() public {
        // Arrange
        uint256 minProposalThresholdPercentageNumerator = governanceProxy.MIN_PROPOSAL_THRESHOLD_PERCENTAGE_NUMERATOR();
        uint256 maxProposalThresholdPercentageNumerator = governanceProxy.MAX_PROPOSAL_THRESHOLD_PERCENTAGE_NUMERATOR();

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceInvalidProposalThresholdPercentageNumerator.selector);
        governanceProxy.setProposalThresholdPercentageNumerator(minProposalThresholdPercentageNumerator - 1);
        vm.expectRevert(IGovernance.GovernanceInvalidProposalThresholdPercentageNumerator.selector);
        governanceProxy.setProposalThresholdPercentageNumerator(maxProposalThresholdPercentageNumerator + 1);
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
        address user = _createUserAndMintMineToken((mineToken.totalSupply() * 53) / 50); // 51% of total supply
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
        address user = _createUserAndMintMineToken((mineToken.totalSupply() * 53) / 50); // 51% of total supply
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

    /**
     * ================ getState() ================
     */

    function test_getState_RevertsWhenProposalIdIsZero() public {
        // Arrange
        uint256 proposalId = 0;

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceInvalidProposalId.selector);
        governanceProxy.getState(proposalId);
    }

    function test_getState_RevertsWhenProposalIdIsTooBig() public {
        // Arrange
        uint256 proposalId = governanceProxy.proposalCount() + 1;

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceInvalidProposalId.selector);
        governanceProxy.getState(proposalId);
    }

    /**
     * ================ getQuorumVotes() ================
     */

    function test_getQuorumVotes_SuccessfullyReturnsValue() public {
        uint256 totalSupply1 = mineToken.totalSupply();
        uint256 quorumVotes1 = governanceProxy.getQuorumVotes();
        assertEq(
            quorumVotes1,
            (totalSupply1 * governanceProxy.quorumVotesPercentageNumerator()) /
                governanceProxy.QUORUM_VOTES_PERCENTAGE_DENOMINATOR()
        );

        vm.prank(wallet);
        mineToken.mint(wallet, 1e18);

        uint256 totalSupply2 = mineToken.totalSupply();
        uint256 quorumVotes2 = governanceProxy.getQuorumVotes();
        assertTrue(totalSupply1 != totalSupply2);
        assertTrue(quorumVotes1 != quorumVotes2);
        assertEq(
            quorumVotes2,
            (totalSupply2 * governanceProxy.quorumVotesPercentageNumerator()) /
                governanceProxy.QUORUM_VOTES_PERCENTAGE_DENOMINATOR()
        );
    }

    /**
     * ================ getQuorumVotes() ================
     */

    function test_getProposalThreshold_SuccessfullyReturnsValue() public {
        uint256 totalSupply1 = mineToken.totalSupply();
        uint256 proposalThreshold1 = governanceProxy.getProposalThreshold();
        assertEq(
            proposalThreshold1,
            (totalSupply1 * governanceProxy.proposalThresholdPercentageNumerator()) /
                governanceProxy.PROPOSAL_THRESHOLD_PERCENTAGE_DENOMINATOR()
        );

        vm.prank(wallet);
        mineToken.mint(wallet, 1e18);

        uint256 totalSupply2 = mineToken.totalSupply();
        uint256 proposalThreshold2 = governanceProxy.getProposalThreshold();
        assertTrue(totalSupply1 != totalSupply2);
        assertTrue(proposalThreshold1 != proposalThreshold2);
        assertEq(
            proposalThreshold2,
            (totalSupply2 * governanceProxy.proposalThresholdPercentageNumerator()) /
                governanceProxy.PROPOSAL_THRESHOLD_PERCENTAGE_DENOMINATOR()
        );
    }
}
