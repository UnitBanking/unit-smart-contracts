// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { GovernanceTestBase } from './GovernanceTestBase.t.sol';
import { IGovernance } from '../../../contracts/interfaces/IGovernance.sol';

contract GovernanceCancelTest is GovernanceTestBase {
    function test_cancel_RevertsWhenProposalAlreadyExecuted() public {
        // Arrange
        uint256 quorumVotes = governanceProxy.quorumVotes();
        address user = _createUserAndMintMineToken(quorumVotes + 1);
        vm.prank(user);
        mineToken.delegate(user);
        governanceProxy.setWhitelistAccountExpiration(user, block.timestamp + 10_000);
        uint256 proposalId = _propose(user);
        _voteAndRollToEndBlock(proposalId, user);
        governanceProxy.queue(proposalId);

        vm.warp(block.timestamp + timelock.delay());
        governanceProxy.execute(proposalId);

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceProposalAlreadyExecuted.selector);
        governanceProxy.cancel(proposalId);
    }

    function test_cancel_RevertsWhenVotesAboveProposalThreshold() public {
        // Arrange
        uint256 quorumVotes = governanceProxy.quorumVotes();
        address user = _createUserAndMintMineToken(quorumVotes + 1);
        vm.prank(user);
        mineToken.delegate(user);
        vm.roll(block.number + 1);
        governanceProxy.setWhitelistAccountExpiration(user, block.timestamp + 10_000);
        uint256 proposalId = _propose(user);

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceVotesAboveProposalThreshold.selector);
        governanceProxy.cancel(proposalId);
    }

    function test_cancel_SuccessfullyCancelsByProposer() public {
        // Arrange
        uint256 quorumVotes = governanceProxy.quorumVotes();
        address user = _createUserAndMintMineToken(quorumVotes + 1);
        vm.prank(user);
        mineToken.delegate(user);
        governanceProxy.setWhitelistAccountExpiration(user, block.timestamp + 10_000);
        uint256 proposalId = _propose(user);

        // Act & Assert
        vm.prank(user);
        vm.expectEmit();
        emit IGovernance.ProposalCanceled(proposalId);
        governanceProxy.cancel(proposalId);
    }

    function test_cancel_RevertsWhenUnauthorizedCanceler() public {
        // Arrange
        uint256 quorumVotes = governanceProxy.quorumVotes();
        address user = _createUserAndMintMineToken(quorumVotes + 1);
        vm.prank(user);
        mineToken.delegate(user);
        governanceProxy.setWhitelistAccountExpiration(user, block.timestamp + 10_000);
        uint256 proposalId = _propose(user);

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceUnauthorizedCanceler.selector);
        governanceProxy.cancel(proposalId);
    }

    function test_cancel_SuccessfullyCancelsByWhitelistGuardianWhenProposerIsWhitelisted() public {
        // Arrange
        uint256 quorumVotes = governanceProxy.quorumVotes();
        address user = _createUserAndMintMineToken(quorumVotes + 1);
        vm.prank(user);
        mineToken.delegate(user);
        governanceProxy.setWhitelistAccountExpiration(user, block.timestamp + 10_000);
        uint256 proposalId = _propose(user);

        // Go below proposal threshold as a whitelisted user
        uint256 balance = mineToken.balanceOf(user);
        vm.prank(user);
        mineToken.burn(balance - 1);

        // Set whitlistGuardian
        governanceProxy.setWhitelistGuardian(address(this));

        // Act & Assert
        vm.expectEmit();
        emit IGovernance.ProposalCanceled(proposalId);
        governanceProxy.cancel(proposalId);

        uint256 proposalState = uint256(governanceProxy.getState(proposalId));
        assertEq(proposalState, uint256(IGovernance.ProposalState.Canceled));
    }

    function test_cancel_SuccessfullyCancelsByWhitelistGuardianWhenProposerIsNotWhitelisted() public {
        // Arrange
        uint256 quorumVotes = governanceProxy.quorumVotes();
        address user = _createUserAndMintMineToken(quorumVotes + 1);
        vm.prank(user);
        mineToken.delegate(user);
        governanceProxy.setWhitelistAccountExpiration(user, block.timestamp + 1);
        uint256 proposalId = _propose(user);

        // Go below proposal threshold as a whitelisted user
        uint256 balance = mineToken.balanceOf(user);
        vm.prank(user);
        mineToken.burn(balance - 1);

        // Go after user whitelist expiration
        vm.warp(block.timestamp + 2);

        // Set whitelistGuardian
        governanceProxy.setWhitelistGuardian(address(this));

        // Act & Assert
        vm.expectEmit();
        emit IGovernance.ProposalCanceled(proposalId);
        governanceProxy.cancel(proposalId);

        uint256 proposalState = uint256(governanceProxy.getState(proposalId));
        assertEq(proposalState, uint256(IGovernance.ProposalState.Canceled));
    }

    function test_cancel_SuccessfullyCancelsByAnySenderWhenProposerIsNotWhitelisted() public {
        // Arrange
        uint256 quorumVotes = governanceProxy.quorumVotes();
        address user = _createUserAndMintMineToken(quorumVotes + 1);
        vm.prank(user);
        mineToken.delegate(user);
        governanceProxy.setWhitelistAccountExpiration(user, block.timestamp + 1);
        uint256 proposalId = _propose(user);

        // Go below proposal threshold as a whitelisted user
        uint256 balance = mineToken.balanceOf(user);
        vm.prank(user);
        mineToken.burn(balance - 1);

        // Go after user whitelist expiration
        vm.warp(block.timestamp + 2);

        // Act & Assert
        vm.expectEmit();
        emit IGovernance.ProposalCanceled(proposalId);
        governanceProxy.cancel(proposalId);

        uint256 proposalState = uint256(governanceProxy.getState(proposalId));
        assertEq(proposalState, uint256(IGovernance.ProposalState.Canceled));
    }
}
