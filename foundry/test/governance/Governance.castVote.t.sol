// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { GovernanceTestBase } from './GovernanceTestBase.t.sol';
import { IGovernance } from '../../../contracts/interfaces/IGovernance.sol';

contract GovernanceCastVoteTest is GovernanceTestBase {
    function test_castVote_SuccessfullyCastsVote() public {
        // Arrange
        uint256 proposalId = _propose(wallet);
        uint256 startBlock = block.number + governanceProxy.votingDelay();
        uint256 balance = 10e18;
        address user = _createUserAndMintMineToken(balance);
        vm.prank(user);
        mineToken.delegate(user);
        vm.roll(startBlock + 1);

        // Act & Assert
        vm.expectEmit();
        emit IGovernance.VoteCast(user, proposalId, 1, balance, '');
        vm.prank(user);
        governanceProxy.castVote(proposalId, 1);
    }

    function test_castVoteWithReason_SuccessfullyCastsAgainstVote() public {
        // Arrange
        uint256 proposalId = _propose(wallet);
        string memory reason = 'vote reason';
        uint256 startBlock = block.number + governanceProxy.votingDelay();
        uint256 balance = 10e18;
        address user = _createUserAndMintMineToken(balance);
        vm.prank(user);
        mineToken.delegate(user);
        vm.roll(startBlock + 1);

        // Act & Assert
        vm.expectEmit();
        emit IGovernance.VoteCast(user, proposalId, 0, balance, reason);
        vm.prank(user);
        governanceProxy.castVoteWithReason(proposalId, 0, reason);

        vm.roll(block.number + 80640);
        IGovernance.ProposalState state = governanceProxy.getState(proposalId);
        assert(state == IGovernance.ProposalState.Defeated);
    }

    function test_castVoteWithReason_SuccessfullyCastsForVote() public {
        // Arrange
        uint256 proposalId = _propose(wallet);
        string memory reason = 'vote reason';
        uint256 startBlock = block.number + governanceProxy.votingDelay();
        uint256 balance = 10e18;
        address user = _createUserAndMintMineToken(balance);
        vm.prank(user);
        mineToken.delegate(user);
        vm.roll(startBlock + 1);

        // Act & Assert
        vm.expectEmit();
        emit IGovernance.VoteCast(user, proposalId, 1, balance, reason);
        vm.prank(user);
        governanceProxy.castVoteWithReason(proposalId, 1, reason);

        vm.roll(block.number + 80640);
        IGovernance.ProposalState state = governanceProxy.getState(proposalId);
        assert(state == IGovernance.ProposalState.Defeated);
    }

    function test_castVoteWithReason_SuccessfullyCastsAbstainVote() public {
        // Arrange
        uint256 proposalId = _propose(wallet);
        string memory reason = 'vote reason';
        uint256 startBlock = block.number + governanceProxy.votingDelay();
        uint256 balance = 10e18;
        address user = _createUserAndMintMineToken(balance);
        vm.prank(user);
        mineToken.delegate(user);
        vm.roll(startBlock + 1);

        // Act & Assert
        vm.expectEmit();
        emit IGovernance.VoteCast(user, proposalId, 2, balance, reason);
        vm.prank(user);
        governanceProxy.castVoteWithReason(proposalId, 2, reason);

        vm.roll(block.number + 80640);
        IGovernance.ProposalState state = governanceProxy.getState(proposalId);
        assert(state == IGovernance.ProposalState.Defeated);
    }

    function test_castVoteWithReason_SuccessfullyCastsVoteAndThenExpired() public {
        // Arrange
        uint256 proposalId = _propose(wallet);
        string memory reason = 'vote reason';
        uint256 startBlock = block.number + governanceProxy.votingDelay();
        uint256 endBlock = startBlock + governanceProxy.votingPeriod();
        uint256 balance = 10000000e18;
        address user = _createUserAndMintMineToken(balance);
        vm.prank(user);
        mineToken.delegate(user);
        vm.roll(startBlock + 1);

        // Act & Assert
        vm.expectEmit();
        emit IGovernance.VoteCast(user, proposalId, 1, balance, reason);
        vm.prank(user);
        governanceProxy.castVoteWithReason(proposalId, 1, reason);

        vm.roll(endBlock + 1);
        governanceProxy.queue(proposalId);

        // make it expired
        vm.warp(block.timestamp + timelock.delay() + timelock.GRACE_PERIOD() + 1);

        IGovernance.ProposalState state = governanceProxy.getState(proposalId);
        assert(state == IGovernance.ProposalState.Expired);
    }

    function test_castVoteBySig_SuccessfullyCastsVote() public {
        // Arrange
        uint256 proposalId = _propose(wallet);
        uint8 support = 1;
        bytes32 domainSeparator = keccak256(
            abi.encode(
                governanceProxy.DOMAIN_TYPEHASH(),
                keccak256(bytes(governanceProxy.name())),
                governanceProxy.exposed_getChainId(),
                address(governanceProxy)
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                domainSeparator,
                keccak256(abi.encode(governanceProxy.BALLOT_TYPEHASH(), proposalId, support))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(2, digest);
        uint256 startBlock = block.number + governanceProxy.votingDelay();
        uint256 balance = 10e18;
        address user = _createUserAndMintMineToken(balance);
        vm.prank(user);
        mineToken.delegate(user);
        vm.roll(startBlock + 1);

        // Act & Assert
        vm.expectEmit();
        emit IGovernance.VoteCast(user, proposalId, support, balance, '');
        vm.prank(wallet);
        governanceProxy.castVoteBySig(proposalId, support, v, r, s);
    }

    function test_castVoteBySig_RevertsWhenSignatureIsWrong() public {
        // Arrange
        uint256 proposalId = _propose(wallet);
        uint8 support = 1;
        string memory name = governanceProxy.name();
        uint256 chainId = governanceProxy.exposed_getChainId();
        bytes32 domainTypehash = governanceProxy.DOMAIN_TYPEHASH();
        bytes32 ballotTypehash = governanceProxy.BALLOT_TYPEHASH();
        bytes32 domainSeparator = keccak256(
            abi.encode(domainTypehash, keccak256(bytes(name)), chainId, address(governanceProxy))
        );
        bytes32 structHash = keccak256(abi.encode(ballotTypehash, proposalId, support));
        bytes32 digest = keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));
        (, bytes32 r, bytes32 s) = vm.sign(2, digest);
        uint8 fakeV = 0;
        uint256 startBlock = block.number + governanceProxy.votingDelay();
        vm.roll(startBlock + 1);

        // Act & Assert
        vm.expectRevert(IGovernance.GovernanceInvalidDelegateSignature.selector);
        vm.prank(wallet);
        governanceProxy.castVoteBySig(proposalId, support, fakeV, r, s);
    }
}
