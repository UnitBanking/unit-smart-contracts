// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { Test } from 'forge-std/Test.sol';
import '../../../contracts/MineAuction.sol';
import '../../../contracts/Proxy.sol';
import '../../../contracts/test/BaseTokenTest.sol';

contract MineAuctionTestCase is Test {
    MineAuction public mineAuction;
    MineToken public mineToken;
    BondingCurve public bondingCurve;
    BaseTokenTest public baseToken;

    address public other = address(0x02);
    address public another = address(0x03);

    error MineAuctionStartTimeTooEarly();
    error MineAuctionInvalidBidAmount();
    error MineAuctionNotCurrentAuctionId(uint256 auctionId);
    error MineAuctionInvalidAuctionGroupId(uint256 auctionGroupId);
    error MineAuctionNotCurrentAuctionGroupId(uint256 auctionGroupId);

    error MineAuctionAuctionGroupIdInFuture(uint256 auctionGroupId);
    error MineAuctionAuctionIdInFuture(uint256 auctionId);
    error MineAuctionAuctionIdInFutureOrCurrent(uint256 auctionId);
    error MineAuctionCurrentAuctionDisabled();

    error MineAuctionInsufficientClaimAmount(uint256 amount);

    function setUp() public {
        bondingCurve = new BondingCurve(address(0x1));

        baseToken = new BaseTokenTest();
        baseToken.initialize();
        baseToken.setMinter(address(this), true);
        baseToken.setBurner(address(this), true);
        baseToken.mint(address(this), 100 * 1 ether);

        mineToken = new MineToken();
        mineToken.initialize();
        mineToken.setMinter(address(this), true);
        mineToken.setBurner(address(this), true);

        mineAuction = new MineAuction(bondingCurve, mineToken, baseToken, uint64(block.timestamp));
        Proxy proxy = new Proxy(address(this));
        proxy.upgradeToAndCall(address(mineAuction), abi.encodeWithSignature('initialize()'));
        mineAuction = MineAuction(address(proxy));

        mineToken.setMinter(address(mineAuction), true);

        baseToken.mint(address(this), 100000 * 1 ether);
        baseToken.mint(other, 100000 * 1 ether);
        baseToken.mint(another, 100000 * 1 ether);
        baseToken.approve(address(mineAuction), type(uint256).max);
        vm.startPrank(other);
        baseToken.approve(address(mineAuction), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(another);
        baseToken.approve(address(mineAuction), type(uint256).max);
        vm.stopPrank();
    }

    function test_canAppendAuctionGroup() public {
        (uint256 startTime, , uint256 bidDuration) = mineAuction.getAuctionGroup(0);
        uint32 expectedBidDuration = 2 * 60 * 60;
        uint32 expectedSettleDuration = 60 * 30;
        mineAuction.addAuctionGroup(
            uint64(startTime) + uint64(bidDuration),
            expectedSettleDuration,
            expectedBidDuration
        );

        uint256 count = mineAuction.getAuctionGroupCount();
        assertEq(count, 2);
        (uint256 lastStartTime, uint256 lastSettleDuration, uint256 lastBidDuration) = mineAuction.getAuctionGroup(
            count - 1
        );
        assertEq(lastStartTime, startTime + bidDuration);
        assertEq(lastSettleDuration, expectedSettleDuration);
        assertEq(lastBidDuration, expectedBidDuration);
    }

    function test_revertIfNewStartTimeIsEarlyThanLast() public {
        (uint256 startTime, , uint256 bidDuration) = mineAuction.getAuctionGroup(0);
        uint32 expectedBidDuration = 2 * 60 * 60;
        uint32 expectedSettleDuration = 60 * 30;
        vm.expectRevert(abi.encodeWithSelector(MineAuctionStartTimeTooEarly.selector));
        mineAuction.addAuctionGroup(
            uint64(startTime) + uint64(bidDuration) - 1,
            expectedSettleDuration,
            expectedBidDuration
        );
    }

    function test_revertIfNewStartTimeIsTooClose() public {
        (uint256 startTime, , uint256 bidDuration) = mineAuction.getAuctionGroup(0);
        uint32 expectedBidDuration = 2 * 60 * 60;
        uint32 expectedSettleDuration = 60 * 30;
        vm.expectRevert(abi.encodeWithSelector(MineAuctionStartTimeTooEarly.selector));
        mineAuction.addAuctionGroup(
            uint64(startTime) + uint64(bidDuration) - 1,
            expectedSettleDuration,
            expectedBidDuration
        );
    }

    function test_canBid() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        assertEq(auctionGroupId, 0);
        mineAuction.bid(auctionGroupId, 0, 101 * 1 ether);
        (uint256 totalBidAmount, uint256 rewardAmount) = mineAuction.getAuction(auctionGroupId, 0);
        assertEq(totalBidAmount, 101 * 1 ether);
        assertGt(rewardAmount, 0);
    }

    function test_allowToAddAuctionGroup() public {
        (uint256 startTime, , uint256 bidDuration) = mineAuction.getAuctionGroup(0);
        uint32 expectedBidDuration = 2 * 60 * 60;
        uint32 expectedSettleDuration = 60 * 30;
        mineAuction.addAuctionGroup(
            uint64(startTime) + uint64(bidDuration),
            expectedSettleDuration,
            expectedBidDuration
        );

        uint256 count = mineAuction.getAuctionGroupCount();
        assertEq(count, 2);
        (uint256 lastStartTime, uint256 lastSettleDuration, uint256 lastBidDuration) = mineAuction.getAuctionGroup(
            count - 1
        );
        assertEq(lastStartTime, startTime + bidDuration);
        assertEq(lastSettleDuration, expectedSettleDuration);
        assertEq(lastBidDuration, expectedBidDuration);
    }

    function test_revertIfTokenNotApproved() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        address someone = address(0x22);
        vm.startPrank(someone);
        baseToken.approve(someone, 0);
        vm.expectRevert();
        mineAuction.bid(auctionGroupId, 0, 100 * 1 ether);
    }

    function test_revertIfBidAmountIsZero() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        vm.expectRevert(abi.encodeWithSelector(MineAuctionInvalidBidAmount.selector));
        mineAuction.bid(auctionGroupId, 0, 0);
    }

    function test_revertIfAuctionGroupOutOfBound() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        vm.expectRevert(abi.encodeWithSelector(MineAuctionInvalidAuctionGroupId.selector, auctionGroupId + 1));
        mineAuction.bid(auctionGroupId + 1, 0, 100 * 1 ether);
    }

    function test_revertIfAuctionGroupIsNotCurrent() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        mineAuction.addAuctionGroup(
            uint64(startTime) + uint64(bidDuration),
            uint32(settleDuration),
            uint32(bidDuration)
        );
        mineAuction.addAuctionGroup(
            uint64(startTime) + uint64(bidDuration) * 2,
            uint32(settleDuration),
            uint32(bidDuration)
        );
        vm.warp(uint64(startTime) + uint64(bidDuration) + 100);
        vm.expectRevert(abi.encodeWithSelector(MineAuctionNotCurrentAuctionGroupId.selector, 0));
        mineAuction.bid(auctionGroupId, 0, 100 * 1 ether);

        vm.expectRevert(abi.encodeWithSelector(MineAuctionNotCurrentAuctionGroupId.selector, 2));
        mineAuction.bid(auctionGroupId + 2, 0, 100 * 1 ether);
    }

    function test_revertIfAuctionIdIsNotCurrent() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        vm.warp(uint64(startTime) + uint64(bidDuration) + uint64(settleDuration) + 100);
        vm.expectRevert(abi.encodeWithSelector(MineAuctionNotCurrentAuctionId.selector, 0));
        mineAuction.bid(auctionGroupId, 0, 100 * 1 ether);

        vm.expectRevert(abi.encodeWithSelector(MineAuctionNotCurrentAuctionId.selector, 2));
        mineAuction.bid(auctionGroupId, 2, 100 * 1 ether);
    }

    function test_revertIfInSettlement() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        vm.warp(uint64(startTime) + uint64(bidDuration) + 100);
        vm.expectRevert(abi.encodeWithSelector(MineAuctionNotCurrentAuctionId.selector, 0));
        mineAuction.bid(auctionGroupId, 0, 100 * 1 ether);
    }

    function test_revertIfGroupIdInFuture() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        mineAuction.addAuctionGroup(
            uint64(startTime) + uint64(bidDuration),
            uint32(settleDuration),
            uint32(bidDuration)
        );

        vm.expectRevert(abi.encodeWithSelector(MineAuctionAuctionGroupIdInFuture.selector, 1));
        mineAuction.getAuction(1, 0);

        vm.expectRevert(abi.encodeWithSelector(MineAuctionAuctionGroupIdInFuture.selector, 1));
        mineAuction.getClaimed(1, 0, address(0x01));

        vm.expectRevert(abi.encodeWithSelector(MineAuctionAuctionGroupIdInFuture.selector, 1));
        mineAuction.getBid(1, 0, address(0x01));
    }

    function test_revertIfAuctionIdInFuture() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        mineAuction.addAuctionGroup(
            uint64(startTime) + uint64(bidDuration),
            uint32(settleDuration),
            uint32(bidDuration)
        );

        vm.expectRevert(abi.encodeWithSelector(MineAuctionAuctionIdInFuture.selector, 1));
        mineAuction.getAuction(0, 1);
    }

    function test_revertIfAuctionGroupIdInvalidInView() public {
        vm.expectRevert(abi.encodeWithSelector(MineAuctionInvalidAuctionGroupId.selector, 1));
        mineAuction.getAuction(1, 0);

        vm.expectRevert(abi.encodeWithSelector(MineAuctionInvalidAuctionGroupId.selector, 1));
        mineAuction.getAuctionGroup(1);

        vm.expectRevert(abi.encodeWithSelector(MineAuctionInvalidAuctionGroupId.selector, 1));
        mineAuction.getClaimed(1, 0, address(0x01));

        vm.expectRevert(abi.encodeWithSelector(MineAuctionInvalidAuctionGroupId.selector, 1));
        mineAuction.getBid(1, 0, address(0x01));
    }

    function test_getAuctionInfo() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        mineAuction.bid(auctionGroupId, 0, 100 * 1 ether);
        (
            uint256 totalBidAmount,
            uint256 rewardAmount,
            uint256 _startTime,
            uint256 _settleDuration,
            uint256 _bidDuration,
            uint256 bidAmount,
            uint256 claimedAmount,
            uint256 claimableAmount
        ) = mineAuction.getAuctionInfo(auctionGroupId, 0, address(this));
        assertEq(totalBidAmount, 100 * 1 ether);
        assertGt(rewardAmount, 0);
        assertEq(_startTime, startTime);
        assertEq(_settleDuration, settleDuration);
        assertEq(_bidDuration, bidDuration);
        assertEq(bidAmount, 100 * 1 ether);
        assertEq(claimedAmount, 0);
        assertGt(claimableAmount, 0);
    }

    function test_revertIfClaimAmountTooLarge() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        mineAuction.bid(auctionGroupId, 0, 100 * 1 ether);
        vm.warp(uint64(startTime) + uint64(bidDuration) + uint64(settleDuration) + 100);
        vm.expectRevert(abi.encodeWithSelector(MineAuctionInsufficientClaimAmount.selector, type(uint256).max));
        mineAuction.claim(auctionGroupId, 0, type(uint256).max);
    }

    function test_canClaim() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        mineAuction.bid(auctionGroupId, 0, 100 * 1 ether);
        vm.warp(uint64(startTime) + uint64(bidDuration) + uint64(settleDuration) + 100);
        uint256 balanceBefore = mineToken.balanceOf(address(this));
        mineAuction.claim(auctionGroupId, 0, 100 * 1 ether);
        uint256 claimedAmount = mineAuction.getClaimed(auctionGroupId, 0, address(this));
        uint256 balanceAfter = mineToken.balanceOf(address(this));
        assertEq(claimedAmount, 100 * 1 ether);
        assertEq(balanceAfter - balanceBefore, 100 * 1 ether);
    }

    function test_canClaimToOther() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        mineAuction.bid(auctionGroupId, 0, 100 * 1 ether);
        vm.warp(uint64(startTime) + uint64(bidDuration) + uint64(settleDuration) + 100);
        uint256 balanceBefore = mineToken.balanceOf(other);
        mineAuction.claim(auctionGroupId, 0, 100 * 1 ether, other);
        uint256 claimedAmount = mineAuction.getClaimed(auctionGroupId, 0, address(this));
        uint256 balanceAfter = mineToken.balanceOf(other);
        assertEq(claimedAmount, 100 * 1 ether);
        assertEq(balanceAfter - balanceBefore, 100 * 1 ether);
    }

    function test_shouldRevertIfInGroupGap() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        mineAuction.addAuctionGroup(
            uint64(startTime) + uint64(bidDuration) + uint32(settleDuration) + 1000,
            uint32(settleDuration),
            uint32(bidDuration)
        );
        vm.warp(uint64(startTime) + uint64(bidDuration) + uint32(settleDuration) + 100);
        vm.expectRevert(abi.encodeWithSelector(MineAuctionCurrentAuctionDisabled.selector));
        mineAuction.bid(auctionGroupId, 0, 100 * 1 ether);
    }
}
