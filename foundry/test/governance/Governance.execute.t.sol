// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { GovernanceTestBase } from './GovernanceTestBase.t.sol';
import { IGovernance } from '../../../contracts/interfaces/IGovernance.sol';

contract GovernanceExecuteTest is GovernanceTestBase {
    function test_execute_RevertsWhenInvalidProposalState() public {
        // Arrange
        uint256 quorumVotes = governanceProxy.quorumVotes();
        address user = _createUserAndMintMineToken(quorumVotes + 1);
        vm.prank(user);
        mineToken.delegate(user);
        governanceProxy.setWhitelistAccountExpiration(user, block.timestamp + 10_000);
        uint256 proposalId = _propose(user);

        // Act
        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernance.GovernanceInvalidProposalState.selector,
                IGovernance.ProposalState.Queued,
                governanceProxy.getState(proposalId)
            )
        );
        governanceProxy.execute(proposalId);
    }

    function test_execute_SuccessfullyExecutesProposal() public {
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

        // Act & Assert
        uint256 userBalanceBefore = mineToken.balanceOf(user);

        vm.expectEmit();
        emit IGovernance.ProposalExecuted(proposalId);
        governanceProxy.execute(proposalId);

        uint256 userBalanceAfter = mineToken.balanceOf(user);
        uint256 proposalState = uint256(governanceProxy.getState(proposalId));
        // Proposal includes transfering 1 MINE token to the proposer's account
        assertEq(userBalanceBefore, userBalanceAfter - 1e18);
        assertEq(proposalState, uint256(IGovernance.ProposalState.Executed));
    }
}
