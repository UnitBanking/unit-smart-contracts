// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { GovernanceTestBase } from './GovernanceTestBase.t.sol';
import { IGovernance } from '../../../contracts/interfaces/IGovernance.sol';

contract GovernanceProposeTest is GovernanceTestBase {
    function test_propose_RevertsWhenVotesBelowProposalThreshold() public {
        // Arrange
        address[] memory targets;
        uint256[] memory values;
        string[] memory signatures;
        bytes[] memory calldatas;

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceVotesBelowProposalThreshold.selector);
        governanceProxy.propose(targets, values, signatures, calldatas, 'proposal #1');
    }

    function test_propose_RevertsWhenArityMismatch() public {
        // Arrange
        address[] memory targets;
        uint256[] memory values = new uint256[](1);
        values[0] = 10;
        string[] memory signatures;
        bytes[] memory calldatas;

        // Act & Assert
        vm.prank(wallet);
        vm.expectRevert(IGovernance.GovernanceArityMismatch.selector);
        governanceProxy.propose(targets, values, signatures, calldatas, 'proposal #1');
    }

    function test_propose_RevertsWhenNoActions() public {
        // Arrange
        address[] memory targets;
        uint256[] memory values;
        string[] memory signatures;
        bytes[] memory calldatas;

        // Act & Assert
        vm.prank(wallet);
        vm.expectRevert(IGovernance.GovernanceNoActions.selector);
        governanceProxy.propose(targets, values, signatures, calldatas, 'proposal #1');
    }

    function test_propose_RevertsWhenTooManyActions() public {
        // Arrange
        uint256 tooManyOperations = governanceProxy.proposalMaxOperations() + 1;
        address[] memory targets = new address[](tooManyOperations);
        uint256[] memory values = new uint256[](tooManyOperations);
        string[] memory signatures = new string[](tooManyOperations);
        bytes[] memory calldatas = new bytes[](tooManyOperations);

        // Act & Assert
        vm.prank(wallet);
        vm.expectRevert(IGovernance.GovernanceTooManyActions.selector);
        governanceProxy.propose(targets, values, signatures, calldatas, 'proposal #1');
    }

    function test_propose_SuccesfullyCreatesProposal() public {
        // Arrange
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = 'proposal #1';

        uint256 startBlock = block.number + governanceProxy.votingDelay();
        uint256 endBlock = startBlock + governanceProxy.votingPeriod();

        // Act
        vm.prank(wallet);
        vm.expectEmit();
        emit IGovernance.ProposalCreated(
            1,
            wallet,
            targets,
            values,
            signatures,
            calldatas,
            startBlock,
            endBlock,
            description
        );
        governanceProxy.propose(targets, values, signatures, calldatas, description);

        // Assert
        uint256 proposalCount = governanceProxy.proposalCount();
        uint256 latestProposalIds = governanceProxy.latestProposalIds(wallet);
        (
            uint256 _id,
            address _proposer,
            uint256 _eta,
            uint256 _startBlock,
            uint256 _endBlock,
            uint256 _forVotes,
            uint256 _againstVotes,
            uint256 _abstainVotes,
            bool _canceled,
            bool _executed
        ) = governanceProxy.proposals(proposalCount);

        assertEq(proposalCount, 1);
        assertEq(latestProposalIds, 1);
        assertEq(_id, 1);
        assertEq(_proposer, wallet);
        assertEq(_eta, 0);
        assertEq(_startBlock, startBlock);
        assertEq(_endBlock, endBlock);
        assertEq(_forVotes, 0);
        assertEq(_againstVotes, 0);
        assertEq(_abstainVotes, 0);
        assertEq(_canceled, false);
        assertEq(_executed, false);
    }

    function test_propose_RevertsWhenAlreadyActiveProposal() public {
        // Arrange
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description1 = 'proposal #1';
        string memory description2 = 'proposal #2';
        uint256 startBlock = block.number + governanceProxy.votingDelay();

        vm.prank(wallet);
        governanceProxy.propose(targets, values, signatures, calldatas, description1);
        vm.roll(startBlock + 1);
        IGovernance.ProposalState state = governanceProxy.getState(1);
        assertEq(uint256(state), uint256(IGovernance.ProposalState.Active));

        // Act & Assert
        vm.prank(wallet);
        vm.expectRevert(IGovernance.GovernanceOnlyOneActiveProposalAllowed.selector);
        governanceProxy.propose(targets, values, signatures, calldatas, description2);
    }

    function test_propose_RevertsWhenAlreadyPendingProposal() public {
        // Arrange
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description1 = 'proposal #1';
        string memory description2 = 'proposal #2';

        vm.prank(wallet);
        governanceProxy.propose(targets, values, signatures, calldatas, description1);

        IGovernance.ProposalState state = governanceProxy.getState(1);
        assertEq(uint256(state), uint256(IGovernance.ProposalState.Pending));

        // Act & Assert
        vm.prank(wallet);
        vm.expectRevert(IGovernance.GovernanceOnlyOnePendingProposalAllowed.selector);
        governanceProxy.propose(targets, values, signatures, calldatas, description2);
    }
}
