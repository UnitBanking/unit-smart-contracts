// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './interfaces/IMineAuction.sol';
import './interfaces/IERC20.sol';
import './abstracts/Ownable.sol';
import './abstracts/Proxiable.sol';
import './MineToken.sol';
import './abstracts/Pausable.sol';
import './libraries/TransferUtils.sol';
import 'hardhat/console.sol';

contract MineAuction is Ownable, IMineAuction, Proxiable, Pausable {
    uint256 constant SECONDS_IN_YEAR = 365 * 24 * 60 * 60;
    uint256 constant SECONDS_IN_FOUR_YEARS = 4 * SECONDS_IN_YEAR;
    uint256 constant AUCTIONABLE_NUMERATOR = 8000;
    uint256 constant AUCTIONABLE_DENOMINATOR = 10000;

    BondingCurve public bondingCurve;
    MineToken public mine;
    IERC20 public bidToken;

    AuctionGroup[] private auctionGroups;
    mapping(uint256 auctionGroupId => mapping(uint256 auctionId => Auction auction)) auctions;

    uint256 public totalAuctionableAmount;
    uint256 public initialAuctionTime;

    function initialize(
        BondingCurve _bondingCurve,
        MineToken _mine,
        IERC20 _bidToken,
        uint256 _initialAuctionTime
    ) external {
        _setOwner(msg.sender);
        _setAuctionGroup(0, 1 hours, 23 hours);
        bondingCurve = _bondingCurve;
        mine = _mine;
        bidToken = _bidToken;
        initialAuctionTime = _initialAuctionTime;
        totalAuctionableAmount = (_mine.MAX_SUPPLY() * AUCTIONABLE_NUMERATOR) / AUCTIONABLE_DENOMINATOR;

        Proxiable.initialize();
    }

    function setAuctionGroup(uint256 startTime, uint256 settleTime, uint256 bidTime) external override onlyOwner {
        revertIfNotInSettlement(startTime);
        _setAuctionGroup(startTime, settleTime, bidTime);
    }

    function getAuctionGroup(
        uint256 auctionGroupId
    ) external view override returns (uint256 startTime, uint256 settleTime, uint256 bidTime) {
        revertIfAuctionGroupNotExist(auctionGroupId);
        AuctionGroup memory auctionGroup = auctionGroups[auctionGroupId];
        startTime = auctionGroup.startTime;
        settleTime = auctionGroup.settleTime;
        bidTime = auctionGroup.bidTime;
    }

    function getCurrentAuctionGroup()
        external
        view
        override
        returns (uint256 startTime, uint256 settleTime, uint256 bidTime)
    {
        AuctionGroup memory auctionGroup = auctionGroups[_currentAuctionGroupId()];
        startTime = auctionGroup.startTime;
        settleTime = auctionGroup.settleTime;
        bidTime = auctionGroup.bidTime;
    }

    function getAuctionGroupCount() external view override returns (uint256) {
        return auctionGroups.length;
    }

    function currentAuctionGroupId() external view override returns (uint256) {
        return _currentAuctionGroupId();
    }

    function getAuction(
        uint256 auctionGroupId,
        uint256 auctionId
    ) external view override returns (uint256 totalBidAmount, uint256 rewardAmount) {
        revertIfAuctionIdInFuture(auctionGroupId, auctionId);
        Auction storage auction = auctions[auctionGroupId][auctionId];
        totalBidAmount = auction.totalBidAmount;
        rewardAmount = auction.rewardAmount;
    }

    function getBid(
        uint256 auctionGroupId,
        uint256 auctionId,
        address bidder
    ) external view override returns (uint256 bidAmount) {
        revertIfAuctionIdInFuture(auctionGroupId, auctionId);
        bidAmount = auctions[auctionGroupId][auctionId].bid[bidder];
    }

    function getClaimed(
        uint256 auctionGroupId,
        uint256 auctionId,
        address bidder
    ) external view override returns (uint256 claimedAmount) {
        revertIfAuctionIdInFuture(auctionGroupId, auctionId);
        claimedAmount = auctions[auctionGroupId][auctionId].claimed[bidder];
    }

    function getAuctionInfo(
        uint256 auctionGroupId,
        uint256 auctionId,
        address bidder
    )
        external
        view
        override
        returns (
            uint256 totalBidAmount,
            uint256 rewardAmount,
            uint256 startTime,
            uint256 settleTime,
            uint256 bidTime,
            uint256 bidAmount,
            uint256 claimedAmount,
            uint256 claimableAmount
        )
    {
        revertIfAuctionIdInFuture(auctionGroupId, auctionId);
        Auction storage auction = auctions[auctionGroupId][auctionId];
        totalBidAmount = auction.totalBidAmount;
        rewardAmount = auction.rewardAmount;
        startTime = auctionGroups[auctionGroupId].startTime;
        settleTime = auctionGroups[auctionGroupId].settleTime;
        bidTime = auctionGroups[auctionGroupId].bidTime;
        bidAmount = auction.bid[bidder];
        claimedAmount = auction.claimed[bidder];
        claimableAmount = getClaimableAmount(auctionGroupId, auctionId, bidder);
    }

    function bid(uint256 auctionId, uint256 amount) external override onlyNotPaused {
        if (amount == 0) {
            revert AuctionInvalidBidAmount();
        }
        if (!isCurrentAuctionId(auctionId)) {
            revert AuctionNotCurrentAuctionId(auctionId);
        }

        uint256 auctionGroupId = _currentAuctionGroupId();

        if (auctions[auctionGroupId][auctionId].rewardAmount == 0) {
            auctions[auctionGroupId][auctionId].rewardAmount = getRewardAmount(auctionGroupId);
        }

        uint256 transferAmount = TransferUtils.safeTransferFrom(bidToken, msg.sender, address(bondingCurve), amount);
        auctions[auctionGroupId][auctionId].totalBidAmount += transferAmount;
        auctions[auctionGroupId][auctionId].bid[msg.sender] += transferAmount;
        emit AuctionBid(auctionGroupId, auctionId, msg.sender, transferAmount);
    }

    function claim(uint256 auctionGroupId, uint256 auctionId, uint256 amount) external override {
        _claim(auctionGroupId, auctionId, msg.sender, msg.sender, amount);
    }

    function claimTo(uint256 auctionGroupId, uint256 auctionId, address to, uint256 amount) external override {
        _claim(auctionGroupId, auctionId, msg.sender, to, amount);
    }

    function _currentAuctionGroupId() internal view returns (uint256) {
        uint256 auctionGroupId = auctionGroups.length - 1;
        for (; auctionGroupId >= 0; auctionGroupId--) {
            if (auctionGroups[auctionGroupId].startTime <= block.timestamp) {
                return auctionGroupId;
            }
        }
        return auctionGroupId;
    }

    function isCurrentAuctionId(uint256 auctionId) internal view returns (bool) {
        AuctionGroup memory auctionGroup = auctionGroups[_currentAuctionGroupId()];
        uint256 startTime = auctionId * (auctionGroup.bidTime + auctionGroup.settleTime) + auctionGroup.startTime;
        uint256 endTime = startTime + auctionGroup.bidTime;
        return block.timestamp >= startTime && block.timestamp < endTime;
    }

    function revertIfAuctionGroupNotExist(uint256 auctionGroupId) internal view {
        if (auctionGroupId > auctionGroups.length - 1) {
            revert AuctionAuctionGroupIdTooLarge(auctionGroupId);
        }
    }

    // should be be able to fetch future auction
    function revertIfAuctionIdInFuture(uint256 auctionGroupId, uint256 auctionId) internal view {
        if (auctionGroupId > _currentAuctionGroupId()) {
            revert AuctionAuctionGroupIdTooLarge(auctionGroupId);
        }
        AuctionGroup memory auctionGroup = auctionGroups[auctionGroupId];
        if (block.timestamp < auctionGroup.startTime + auctionId * (auctionGroup.bidTime + auctionGroup.settleTime)) {
            revert AuctionAuctionIdTooLarge(auctionId);
        }
    }

    // claim is only enabled for past auction, exclude current auction
    function revertIfNotClaimable(uint256 auctionGroupId, uint256 auctionId) internal view {
        if (auctionGroupId > _currentAuctionGroupId()) {
            revert AuctionAuctionGroupIdTooLarge(auctionGroupId);
        }
        AuctionGroup memory auctionGroup = auctionGroups[auctionGroupId];
        if (
            block.timestamp <
            auctionGroup.startTime + (auctionId + 1) * (auctionGroup.bidTime + auctionGroup.settleTime)
        ) {
            revert AuctionAuctionIdTooLarge(auctionId);
        }
    }

    function _claim(uint256 auctionGroupId, uint256 auctionId, address bidder, address to, uint256 amount) internal {
        revertIfNotClaimable(auctionGroupId, auctionId);
        uint256 claimable = getClaimableAmount(auctionGroupId, auctionId, bidder);
        if (amount > claimable) {
            revert AuctionInvalidClaimAmount(amount);
        }
        auctions[auctionGroupId][auctionId].claimed[bidder] += amount;
        mine.mint(to, amount);
        emit AuctionClaimed(auctionGroupId, auctionId, bidder, amount);
    }

    //TODO: use prb math to optimize
    function getRewardAmount(uint256 auctionGroupId) internal view returns (uint256) {
        AuctionGroup memory auctionGroup = auctionGroups[auctionGroupId];
        uint256 elapsed = block.timestamp - initialAuctionTime;
        uint256 period = (elapsed / SECONDS_IN_FOUR_YEARS) + 1;
        uint256 auctionableAmount = totalAuctionableAmount >> period;
        return (auctionableAmount * (auctionGroup.bidTime + auctionGroup.settleTime)) / SECONDS_IN_FOUR_YEARS;
    }

    function getClaimableAmount(
        uint256 auctionGroupId,
        uint256 auctionId,
        address bidder
    ) internal view returns (uint256) {
        if (auctions[auctionGroupId][auctionId].totalBidAmount == 0) {
            return 0;
        }
        Auction storage auction = auctions[auctionGroupId][auctionId];
        //TODO: use prb-math
        uint256 totalClaimable = (auction.bid[bidder] * auction.rewardAmount) / auction.totalBidAmount;
        return totalClaimable - auction.claimed[bidder];
    }

    function _setAuctionGroup(uint256 startTime, uint256 settleTime, uint256 bidTime) internal {
        AuctionGroup memory auctionGroup;
        auctionGroup.startTime = startTime;
        auctionGroup.settleTime = settleTime;
        auctionGroup.bidTime = bidTime;
        auctionGroups.push(auctionGroup);
        emit AuctionGroupSet(auctionGroups.length - 1, startTime, settleTime, bidTime);
    }

    function revertIfNotInSettlement(uint256 startTime) internal view {
        uint256 auctionGroupId = _currentAuctionGroupId();
        AuctionGroup memory auctionGroup = auctionGroups[auctionGroupId];
        uint256 auctionDuration = auctionGroup.bidTime + auctionGroup.settleTime;
        unchecked {
            // Overflow not possible: previously checked
            uint256 elapsed = (block.timestamp - auctionGroup.startTime) % auctionDuration;
            // Overflow not possible: auctionInterval > auctionSettleTime
            if (elapsed < auctionGroup.bidTime) {
                revert AuctionBiddingInProgress();
            }
            uint256 offset = (startTime - auctionGroup.startTime) % auctionDuration;
            if (offset < auctionGroup.bidTime || startTime > block.timestamp - elapsed + auctionDuration) {
                revert AuctionGroupStartTimeNotInSettlement();
            }
        }
    }

    receive() external payable {
        revert AuctionNoDirectTransfer();
    }
}
