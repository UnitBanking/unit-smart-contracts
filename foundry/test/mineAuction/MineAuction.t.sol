pragma solidity 0.8.21;

import './MineAuctionTestBase.t.sol';
import { TransferUtils } from '../../../contracts/libraries/TransferUtils.sol';
import { IMineAuction } from '../../../contracts/interfaces/IMineAuction.sol';

contract MineAuctionTest is MineAuctionTestBase {
    function test_addAuctionGroup_UserCanAppendAuctionGroup() public {
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

    function test_addAuctionGroup_RevertsIfNewStartTimeIsEarlyThanLast() public {
        (uint256 startTime, , uint256 bidDuration) = mineAuction.getAuctionGroup(0);
        uint32 expectedBidDuration = 2 * 60 * 60;
        uint32 expectedSettleDuration = 60 * 30;
        vm.expectRevert(abi.encodeWithSelector(IMineAuction.MineAuctionStartTimeTooEarly.selector));
        mineAuction.addAuctionGroup(
            uint64(startTime) + uint64(bidDuration) - 1,
            expectedSettleDuration,
            expectedBidDuration
        );
    }

    function test_bid_UserCanBid() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        assertEq(auctionGroupId, 0);
        mineAuction.bid(auctionGroupId, 0, 101 * 1 ether);
        (uint256 totalBidAmount, uint256 rewardAmount) = mineAuction.getAuction(auctionGroupId, 0);
        assertEq(totalBidAmount, 101 * 1 ether);
        assertGt(rewardAmount, 0);
    }

    function test_bid_RevertsIfTokenNotApproved() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        address someone = address(0x22);
        vm.prank(someone);
        baseToken.approve(address(mineAuction), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                TransferUtils.TransferUtilsERC20TransferFromFailed.selector,
                address(baseToken),
                someone,
                address(bondingCurve),
                100 * 1 ether
            )
        );
        vm.prank(someone);
        mineAuction.bid(auctionGroupId, 0, 100 * 1 ether);
    }

    function test_bid_RevertsIfBidAmountIsZero() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        vm.expectRevert(abi.encodeWithSelector(IMineAuction.MineAuctionInvalidBidAmount.selector));
        mineAuction.bid(auctionGroupId, 0, 0);
    }

    function test_bid_RevertsIfAuctionGroupOutOfBound() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        vm.expectRevert(
            abi.encodeWithSelector(IMineAuction.MineAuctionInvalidAuctionGroupId.selector, auctionGroupId + 1)
        );
        mineAuction.bid(auctionGroupId + 1, 0, 100 * 1 ether);
    }

    function test_bid_RevertIfAuctionGroupIsNotCurrent() public {
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
        vm.expectRevert(abi.encodeWithSelector(IMineAuction.MineAuctionNotCurrentAuctionGroupId.selector, 0));
        mineAuction.bid(auctionGroupId, 0, 100 * 1 ether);

        vm.expectRevert(abi.encodeWithSelector(IMineAuction.MineAuctionNotCurrentAuctionGroupId.selector, 2));
        mineAuction.bid(auctionGroupId + 2, 0, 100 * 1 ether);
    }

    function test_bid_RevertsIfAuctionIdIsNotCurrent() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        vm.warp(uint64(startTime) + uint64(bidDuration) + uint64(settleDuration) + 100);
        vm.expectRevert(abi.encodeWithSelector(IMineAuction.MineAuctionNotCurrentAuctionId.selector, 0));
        mineAuction.bid(auctionGroupId, 0, 100 * 1 ether);

        vm.expectRevert(abi.encodeWithSelector(IMineAuction.MineAuctionNotCurrentAuctionId.selector, 2));
        mineAuction.bid(auctionGroupId, 2, 100 * 1 ether);
    }

    function test_bid_RevertsIfInSettlement() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        vm.warp(uint64(startTime) + uint64(bidDuration) + 100);
        vm.expectRevert(abi.encodeWithSelector(IMineAuction.MineAuctionNotCurrentAuctionId.selector, 0));
        mineAuction.bid(auctionGroupId, 0, 100 * 1 ether);
    }

    function test_view_RevertsIfGroupIdInFuture() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        mineAuction.addAuctionGroup(
            uint64(startTime) + uint64(bidDuration),
            uint32(settleDuration),
            uint32(bidDuration)
        );

        vm.expectRevert(abi.encodeWithSelector(IMineAuction.MineAuctionAuctionGroupIdInFuture.selector, 1));
        mineAuction.getAuction(1, 0);

        vm.expectRevert(abi.encodeWithSelector(IMineAuction.MineAuctionAuctionGroupIdInFuture.selector, 1));
        mineAuction.getClaimed(1, 0, address(0x01));

        vm.expectRevert(abi.encodeWithSelector(IMineAuction.MineAuctionAuctionGroupIdInFuture.selector, 1));
        mineAuction.getBid(1, 0, address(0x01));
    }

    function test_getAuction_RevertsIfAuctionIdInFuture() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        mineAuction.addAuctionGroup(
            uint64(startTime) + uint64(bidDuration),
            uint32(settleDuration),
            uint32(bidDuration)
        );

        vm.expectRevert(abi.encodeWithSelector(IMineAuction.MineAuctionAuctionIdInFuture.selector, 1));
        mineAuction.getAuction(0, 1);
    }

    function test_view_RevertsIfAuctionGroupIdInvalidInView() public {
        vm.expectRevert(abi.encodeWithSelector(IMineAuction.MineAuctionInvalidAuctionGroupId.selector, 1));
        mineAuction.getAuction(1, 0);

        vm.expectRevert(abi.encodeWithSelector(IMineAuction.MineAuctionInvalidAuctionGroupId.selector, 1));
        mineAuction.getAuctionGroup(1);

        vm.expectRevert(abi.encodeWithSelector(IMineAuction.MineAuctionInvalidAuctionGroupId.selector, 1));
        mineAuction.getClaimed(1, 0, address(0x01));

        vm.expectRevert(abi.encodeWithSelector(IMineAuction.MineAuctionInvalidAuctionGroupId.selector, 1));
        mineAuction.getBid(1, 0, address(0x01));
    }

    function test_getAuctionInfo_ValidAuctionInfo() public {
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

    function test_claim_RevertsIfClaimAmountTooLarge() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        mineAuction.bid(auctionGroupId, 0, 100 * 1 ether);
        vm.warp(uint64(startTime) + uint64(bidDuration) + uint64(settleDuration) + 100);
        vm.expectRevert(
            abi.encodeWithSelector(IMineAuction.MineAuctionInsufficientClaimAmount.selector, type(uint256).max)
        );
        mineAuction.claim(auctionGroupId, 0, type(uint256).max);
    }

    function test_claim_UserCanClaim() public {
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

    function test_claim_UserCanClaimToOther() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        mineAuction.bid(auctionGroupId, 0, 100 * 1 ether);
        vm.warp(uint64(startTime) + uint64(bidDuration) + uint64(settleDuration) + 100);
        uint256 balanceBefore = mineToken.balanceOf(other);
        uint256 balanceBidderBefore = mineToken.balanceOf(address(this));
        mineAuction.claim(auctionGroupId, 0, 100 * 1 ether, other);
        uint256 balanceBidderAfter = mineToken.balanceOf(address(this));
        uint256 claimedAmount = mineAuction.getClaimed(auctionGroupId, 0, address(this));
        uint256 balanceAfter = mineToken.balanceOf(other);
        assertEq(claimedAmount, 100 * 1 ether);
        assertEq(balanceAfter - balanceBefore, 100 * 1 ether);
        assertEq(balanceBidderBefore, balanceBidderAfter);
    }

    function test_bid_RevertsIfInGroupGap() public {
        (uint256 auctionGroupId, uint256 startTime, uint256 settleDuration, uint256 bidDuration) = mineAuction
            .getCurrentAuctionGroup();
        mineAuction.addAuctionGroup(
            uint64(startTime) + uint64(bidDuration) + uint32(settleDuration) + 1000,
            uint32(settleDuration),
            uint32(bidDuration)
        );
        vm.warp(uint64(startTime) + uint64(bidDuration) + uint32(settleDuration) + 100);
        vm.expectRevert(abi.encodeWithSelector(IMineAuction.MineAuctionCurrentAuctionDisabled.selector));
        mineAuction.bid(auctionGroupId, 0, 100 * 1 ether);
    }
}
