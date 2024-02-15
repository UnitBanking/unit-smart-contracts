// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { GovernanceTestBase } from './GovernanceTestBase.t.sol';
import { IGovernance } from '../../../contracts/interfaces/IGovernance.sol';

contract GovernanceCastVoteTest is GovernanceTestBase {
    function test_castVote_SuccessfullyCastsVote() public {
        // Arrange
        uint256 proposalId = _propose(wallet);
        uint256 startBlock = block.number + governanceProxy.votingDelay();
        address user = _createUserAndMintMineToken(10e18);
        vm.roll(startBlock + 1);

        // Act & Assert
        vm.expectEmit();
        emit IGovernance.VoteCast(user, proposalId, 1, 0, '');
        vm.prank(user);
        governanceProxy.castVote(proposalId, 1);
    }

    function test_castVoteWithReason_SuccessfullyCastsVote() public {
        // Arrange
        uint256 proposalId = _propose(wallet);
        string memory reason = 'vote reason';
        uint256 startBlock = block.number + governanceProxy.votingDelay();
        address user = _createUserAndMintMineToken(10e18);
        vm.roll(startBlock + 1);

        // Act & Assert
        vm.expectEmit();
        emit IGovernance.VoteCast(user, proposalId, 1, 0, reason);
        vm.prank(user);
        governanceProxy.castVoteWithReason(proposalId, 1, reason);
    }

    function test_castVoteBySig_SuccessfullyCastsVote() public {
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
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(2, digest);
        uint256 startBlock = block.number + governanceProxy.votingDelay();
        address user = _createUserAndMintMineToken(10e18);
        vm.roll(startBlock + 1);

        // Act & Assert
        vm.expectEmit();
        emit IGovernance.VoteCast(user, proposalId, support, 0, '');
        vm.prank(wallet);
        governanceProxy.castVoteBySig(proposalId, support, v, r, s);
    }
}
