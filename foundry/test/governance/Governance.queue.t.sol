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

    function _propose(address proposer) private returns (uint256 proposalId) {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = 'proposal #1';

        vm.prank(proposer);
        governanceProxy.propose(targets, values, signatures, calldatas, description);

        proposalId = governanceProxy.proposalCount();
    }
}
