// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import 'forge-std/console.sol';
import { Test } from 'forge-std/Test.sol';
import { MineTokenTestBase } from './MineTokenTestBase.t.sol';
import { Proxy } from '../../../contracts/Proxy.sol';
import { MineToken } from '../../../contracts/MineToken.sol';
import { IVotes } from '../../../contracts/interfaces/IVote.sol';
import '../utils/SigUtils.sol';

contract MineTokenDelegationTest is MineTokenTestBase {
    SigUtils internal sigUtils;
    uint256 internal ownerPrivateKey = 0xA11CE;
    uint256 internal spenderPrivateKey = 0xB0B;

    address internal owner = vm.addr(ownerPrivateKey);
    address internal spender = vm.addr(spenderPrivateKey);

    event DelegateSet(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesSet(address indexed delegate, uint256 previousBalance, uint256 newBalance);
    event DefaultDelegateeSet(address indexed oldDefaultDelegate, address indexed newDefaultDelegate);

    function setUp() public override {
        super.setUp();
        sigUtils = new SigUtils(
            keccak256(
                abi.encode(
                    mineToken.DOMAIN_TYPEHASH(),
                    keccak256(bytes(mineToken.name())),
                    block.chainid,
                    address(mineToken)
                )
            )
        );
    }

    function test_delegate_UserCanDelegate() public {
        address delegatee = address(0x123);
        mineToken.delegate(delegatee);
        assertEq(mineToken.delegatees(address(this)), delegatee);
    }

    function test_mint_MintSetDefaultDelegatee() public {
        address other = address(0x123);
        address defaultDelegatee = mineToken.defaultDelegatee();
        mineToken.mint(other, 100 * 1 ether);
        assertEq(mineToken.delegatees(address(other)), defaultDelegatee);
        uint256 total = mineToken.balanceOf(other);
        assertLt(mineToken.getCurrentVotes(defaultDelegatee), total);
    }

    function test_delegate_TransferShouldSetDelegateeAsDefaultDelegatee() public {
        mineToken.mint(address(this), 100 * 1 ether);
        address delegatee = address(0x123);
        mineToken.delegate(delegatee);
        address other = address(0x1234);
        assertEq(mineToken.delegatees(address(this)), delegatee);
        mineToken.transfer(other, 100 * 1 ether);
        assertEq(mineToken.delegatees(other), mineToken.defaultDelegatee());
    }

    function test_delegate_DelegateShouldEmitEvent() public {
        address delegatee = address(0x123);
        vm.expectEmit(true, true, true, true);
        emit DelegateSet(address(this), mineToken.delegatees(address(this)), delegatee);
        emit DelegateVotesSet(delegatee, 0, 100 * 1 ether);
        mineToken.delegate(delegatee);
        assertEq(mineToken.delegatees(address(this)), delegatee);
    }

    function test_delegate_ShouldDelegateToDefaultDelegatee() public {
        address delegatee = address(0x123);
        mineToken.delegate(delegatee);
        assertEq(mineToken.delegatees(address(this)), delegatee);
        mineToken.delegate(mineToken.defaultDelegatee());
        assertEq(mineToken.delegatees(address(this)), mineToken.defaultDelegatee());
    }

    function test_getCurrentVotes_InitialVoteZero() public {
        assertEq(mineToken.getCurrentVotes(address(this)), 0);
    }

    function test_getCurrentVotes_DefaultVoteToDefaultDelegatee() public {
        assertEq(mineToken.getCurrentVotes(mineToken.defaultDelegatee()), 0);
    }

    function test_delegate_BurnMintUpdateVotes() public {
        mineToken.mint(address(this), 100 * 1 ether);
        address delegatee = address(0x123);
        mineToken.delegate(delegatee);
        mineToken.burn(100 * 1 ether);
        assertEq(mineToken.getCurrentVotes(delegatee), 0);
        mineToken.mint(address(this), 100 * 1 ether);
        assertEq(mineToken.getCurrentVotes(delegatee), 100 * 1 ether);
    }

    function test_delegate_VotesAfterDelegate() public {
        mineToken.mint(address(this), 100 * 1 ether);
        address delegatee = address(0x123);
        mineToken.delegate(delegatee);
        assertEq(mineToken.getCurrentVotes(delegatee), 100 * 1 ether);
    }

    function test_delegate_GetPriorVotes() public {
        mineToken.mint(address(this), 100 * 1 ether);
        address delegatee = address(0x123);
        uint256 blockNumber = block.number;
        mineToken.delegate(delegatee);
        vm.roll(blockNumber + 1);
        assertEq(mineToken.getPriorVotes(delegatee, blockNumber), 100 * 1 ether);
        assertEq(mineToken.getPriorVotes(delegatee, blockNumber - 1), 0);
    }

    function test_setDefaultDelegatee_UpdateDefaultDelegateeAndGetPriorVotes() public {
        address defaultDelegatee = mineToken.defaultDelegatee();
        uint256 votesBefore = mineToken.getCurrentVotes(defaultDelegatee);
        mineToken.mint(address(this), 100 * 1 ether);
        uint256 votesAfter = mineToken.getCurrentVotes(defaultDelegatee);
        uint256 blockNumber = block.number;
        vm.roll(block.number + 1);
        address delegatee = address(0x123);
        mineToken.setDefaultDelegatee(delegatee);
        assertEq(mineToken.getPriorVotes(defaultDelegatee, blockNumber), votesAfter - votesBefore);
        assertEq(mineToken.getCurrentVotes(delegatee), votesAfter - votesBefore);
        assertEq(mineToken.getCurrentVotes(defaultDelegatee), 0);
    }

    function test_delegation_UpdateVotesAfterMint() public {
        address delegatee = address(0x123);
        mineToken.delegate(delegatee);
        mineToken.mint(address(this), 100 * 1 ether);
        assertEq(mineToken.getCurrentVotes(delegatee), 100 * 1 ether);
    }

    function test_delegation_RevertsIfBlockNumberIsTooHigh() public {
        mineToken.mint(address(this), 100 * 1 ether);
        vm.expectRevert(abi.encodeWithSelector(IVotes.VotesBlockNumberTooHigh.selector, block.number + 10));
        mineToken.getPriorVotes(address(this), block.number + 10);
    }

    function test_delegation_DelegateBySig() public {
        uint256 nonce = mineToken.nonces(owner);
        uint256 expiry = block.timestamp + 100;
        SigUtils.Delegation memory delegation = SigUtils.Delegation({
            delegatee: spender,
            nonce: nonce,
            deadline: expiry
        });
        bytes32 digest = sigUtils.getDelegateTypedDataHash(delegation);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        mineToken.delegateBySig(spender, nonce, expiry, v, r, s);
        assertEq(mineToken.delegatees(owner), spender);
    }
}
