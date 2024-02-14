// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { GovernanceTestBase } from './GovernanceTestBase.t.sol';
import { IGovernance } from '../../../contracts/interfaces/IGovernance.sol';

contract GovernanceCastVoteTest is GovernanceTestBase {
    function test_exposed_castVote_SuccessfullyCastsVote() public {
        // Arrange
        governanceProxy.setWhitelistAccountExpiration(wallet, block.timestamp + 10);
        uint256 proposalId = _propose(wallet);
        uint256 startBlock = block.number + governanceProxy.votingDelay();
        address user = _createUserAndMintMineToken(10e18);
        vm.roll(startBlock + 1);

        // Act & Assert
        vm.prank(user);
        governanceProxy.exposed_castVote(proposalId, 1);

        IGovernance.Receipt memory receipt = governanceProxy.getReceipt(proposalId, user);
        assertEq(receipt.hasVoted, true);
        assertEq(receipt.support, 1);
        assertEq(receipt.votes, 0);
    }

    function test_exposed_castVote_RevertsWhenInvalidVoteType() public {
        // Arrange
        governanceProxy.setWhitelistAccountExpiration(wallet, block.timestamp + 10);
        uint256 proposalId = _propose(wallet);
        uint256 startBlock = block.number + governanceProxy.votingDelay();
        address user = _createUserAndMintMineToken(10e18);
        vm.roll(startBlock + 1);
        uint8 invalidVoteType = 3;

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(IGovernance.GovernanceInvalidVoteType.selector);
        governanceProxy.exposed_castVote(proposalId, invalidVoteType);
    }

    function test_exposed_castVote_RevertsWhenVotingClosed() public {
        // Arrange
        governanceProxy.setWhitelistAccountExpiration(wallet, block.timestamp + 10);
        uint256 proposalId = _propose(wallet);
        address user = _createUserAndMintMineToken(10e18);

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(IGovernance.GovernanceVotingClosed.selector);
        governanceProxy.exposed_castVote(proposalId, 1);
    }

    function test_exposed_castVote_RevertsWhenVoterAlreadyVoted() public {
        // Arrange
        governanceProxy.setWhitelistAccountExpiration(wallet, block.timestamp + 10);
        uint256 proposalId = _propose(wallet);
        uint256 startBlock = block.number + governanceProxy.votingDelay();
        address user = _createUserAndMintMineToken(10e18);
        vm.roll(startBlock + 1);

        vm.prank(user);
        governanceProxy.exposed_castVote(proposalId, 1);

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(IGovernance.GovernanceVoterAlreadyVoted.selector);
        governanceProxy.exposed_castVote(proposalId, 1);
    }
}
