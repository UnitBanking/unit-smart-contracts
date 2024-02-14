// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { GovernanceTestBase } from './GovernanceTestBase.t.sol';
import { IGovernance } from '../../../contracts/interfaces/IGovernance.sol';

contract GovernanceQueueTest is GovernanceTestBase {
    function test_queue_RevertsWhenInvalidProposalState() public {
        // Arrange
        governanceProxy.setWhitelistAccountExpiration(wallet, block.timestamp + 10);
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
}
