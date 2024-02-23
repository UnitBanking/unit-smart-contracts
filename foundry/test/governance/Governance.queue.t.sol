// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { GovernanceTestBase } from './GovernanceTestBase.t.sol';
import { IGovernance } from '../../../contracts/interfaces/IGovernance.sol';

contract GovernanceQueueTest is GovernanceTestBase {
    function test_queue_RevertsWhenInvalidProposalState() public {
        // Arrange
        uint256 proposalId = _propose(wallet);

        // Act & Assert
        IGovernance.ProposalState state = governanceProxy.getState(proposalId);
        vm.expectRevert(
            abi.encodeWithSelector(
                IGovernance.GovernanceInvalidProposalState.selector,
                IGovernance.ProposalState.Succeeded,
                state
            )
        );
        governanceProxy.queue(proposalId);
    }

    function test_queue_RevertsWhenDuplicatedProposal() public {
        // Arrange
        address user = _createUserAndMintMineToken((mineToken.totalSupply() * 53) / 50); // 51% of total supply
        vm.prank(user);
        mineToken.delegate(user);
        governanceProxy.setWhitelistAccountExpiration(user, block.timestamp + 10_000);
        uint256 proposalId = _proposeWithDuplicatedTxs(user);
        _voteAndRollToEndBlock(proposalId, user);

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceDuplicatedProposal.selector);
        governanceProxy.queue(proposalId);
    }

    function test_queue_SuccessfullyQueuesProposal() public {
        // Arrange
        address user = _createUserAndMintMineToken((mineToken.totalSupply() * 53) / 50); // 51% of total supply
        vm.prank(user);
        mineToken.delegate(user);
        governanceProxy.setWhitelistAccountExpiration(user, block.timestamp + 10_000);
        uint256 proposalId = _propose(user);
        _voteAndRollToEndBlock(proposalId, user);

        // Act & Assert
        vm.expectEmit();
        emit IGovernance.ProposalQueued(proposalId, block.timestamp + timelock.delay());
        governanceProxy.queue(proposalId);
    }
}
