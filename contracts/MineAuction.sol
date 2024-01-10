// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './interfaces/IMineAuction.sol';
import './interfaces/IERC20.sol';
import './abstracts/Ownable.sol';
import './abstracts/Proxiable.sol';
import './libraries/TransferHelper.sol';
import './MineToken.sol';

contract MineAuction is Ownable, IMineAuction, Proxiable {
    uint8 public constant MINIMUM_AUCTION_INTERVAL = 12;
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

    function initialize(BondingCurve _bondingCurve, MineToken _mine, IERC20 _bidToken) external {
        _setOwner(msg.sender);
        _setAuctionGroup(0, 1 hours, 24 hours);
        bondingCurve = _bondingCurve;
        mine = _mine;
        bidToken = _bidToken;

        initialAuctionTime = block.timestamp;
        totalAuctionableAmount = (_mine.MAX_SUPPLY() * AUCTIONABLE_NUMERATOR) / AUCTIONABLE_DENOMINATOR;

        Proxiable.initialize();
    }

    function setIntialAuctionTime(uint256 _initialAuctionTime) external override onlyOwner {
        initialAuctionTime = _initialAuctionTime;
        emit InitialAuctionTimeSet(_initialAuctionTime);
    }

    function setAuctionGroup(uint256 startTime, uint256 settleTime, uint256 interval) external override onlyOwner {
        revertIfAuctionBiddingInProgress();
        if (startTime < block.timestamp) {
            revert AuctionStartTimeInThePast();
        }
        if (interval < MINIMUM_AUCTION_INTERVAL || interval <= settleTime) {
            revert AuctionInvalidInterval(interval);
        }
        unchecked {
            // Overflow not possible: interval > settleTime
            if (interval - settleTime <= MINIMUM_AUCTION_INTERVAL) {
                revert AuctionInvalidSettleTime(settleTime);
            }
        }
        _setAuctionGroup(startTime, settleTime, interval);
    }

    function getAuctionGroup(
        uint256 auctionGroupId
    ) external view override returns (uint256 startTime, uint256 settleTime, uint256 interval) {
        validateAuctionGroupId(auctionGroupId);
        AuctionGroup memory auctionGroup = auctionGroups[auctionGroupId];
        startTime = auctionGroup.startTime;
        settleTime = auctionGroup.settleTime;
        interval = auctionGroup.interval;
    }

    function getCurrentAuctionGroup()
        external
        view
        override
        returns (uint256 startTime, uint256 settleTime, uint256 interval)
    {
        AuctionGroup memory auctionGroup = auctionGroups[currentAuctionGroupId()];
        startTime = auctionGroup.startTime;
        settleTime = auctionGroup.settleTime;
        interval = auctionGroup.interval;
    }

    function currentAuctionGroupId() public view override returns (uint256) {
        return auctionGroups.length - 1;
    }

    function getAuction(
        uint256 auctionGroupId,
        uint256 auctionId
    ) external view override returns (uint256 totalBidAmount, uint256 rewardAmount) {
        validateAuctionId(auctionGroupId, auctionId);
        Auction storage auction = auctions[auctionGroupId][auctionId];
        totalBidAmount = auction.totalBidAmount;
        rewardAmount = auction.rewardAmount;
    }

    function getBid(
        uint256 auctionGroupId,
        uint256 auctionId,
        address bidder
    ) external view override returns (uint256 bidAmount) {
        validateAuctionId(auctionGroupId, auctionId);
        bidAmount = auctions[auctionGroupId][auctionId].bid[bidder];
    }

    function getClaimed(
        uint256 auctionGroupId,
        uint256 auctionId,
        address bidder
    ) external view override returns (uint256 claimedAmount) {
        validateAuctionId(auctionGroupId, auctionId);
        claimedAmount = auctions[auctionGroupId][auctionId].claimed[bidder];
    }

    function bid(uint256 auctionId, uint256 amount) external override {
        if (amount == 0) {
            revert AuctionInvalidBidAmount();
        }

        if (!isCurrentAuctionId(auctionId)) {
            revert AuctionNotCurrentAuctionId(auctionId);
        }

        uint256 auctionGroupId = currentAuctionGroupId();

        auctions[auctionGroupId][auctionId].totalBidAmount += amount;
        auctions[auctionGroupId][auctionId].bid[msg.sender] += amount;

        if (auctions[auctionGroupId][auctionId].rewardAmount == 0) {
            auctions[auctionGroupId][auctionId].rewardAmount = getRewardAmount();
        }

        TransferHelper.safeTransferFrom(bidToken, msg.sender, address(bondingCurve), amount);
        emit AuctionBid(auctionGroupId, auctionId, msg.sender, amount);
    }

    function claim(uint256 auctionGroupId, uint256 auctionId, uint256 amount) external override {
        _claim(auctionGroupId, auctionId, msg.sender, msg.sender, amount);
    }

    function claimTo(uint256 auctionGroupId, uint256 auctionId, address to, uint256 amount) external override {
        _claim(auctionGroupId, auctionId, msg.sender, to, amount);
    }

    function isCurrentAuctionId(uint256 auctionId) internal view returns (bool) {
        AuctionGroup memory auctionGroup = auctionGroups[currentAuctionGroupId()];
        unchecked {
            uint256 previousAuctionDuration = auctionId * auctionGroup.interval;
            uint256 startTime = previousAuctionDuration + auctionGroup.startTime;
            uint256 endTime = startTime + auctionGroup.interval - auctionGroup.settleTime;
            return block.timestamp >= startTime && block.timestamp < endTime;
        }
    }

    function validateAuctionGroupId(uint256 auctionGroupId) internal view {
        if (auctionGroupId > currentAuctionGroupId()) {
            revert AuctionAuctionGroupIdTooLarge(auctionGroupId);
        }
    }

    function validateAuctionId(uint256 auctionGroupId, uint256 auctionId) internal view {
        uint256 groupId = currentAuctionGroupId();
        if (auctionGroupId > groupId) {
            revert AuctionAuctionGroupIdTooLarge(auctionGroupId);
        }
        AuctionGroup memory auctionGroup = auctionGroups[groupId];
        uint256 previousAuctionDuration = auctionId * auctionGroup.interval;
        uint256 startTime = previousAuctionDuration + auctionGroup.startTime;
        if (block.timestamp < startTime) {
            revert AuctionAuctionIdTooLarge(auctionId);
        }
    }

    function _claim(uint256 auctionGroupId, uint256 auctionId, address bidder, address to, uint256 amount) internal {
        if (auctionGroupId == currentAuctionGroupId() && isCurrentAuctionId(auctionId)) {
            revert AuctionClaimingCurrentAuction();
        }
        uint256 claimable = getClaimableAmount(auctionGroupId, auctionId, bidder);
        if (amount > claimable) {
            revert AuctionInvalidClaimAmount(amount);
        }
        auctions[auctionGroupId][auctionId].claimed[bidder] += amount;
        mine.mint(to, amount);
        emit AuctionClaimed(auctionGroupId, auctionId, bidder, amount);
    }

    //TODO: use prb math to optimize
    function getRewardAmount() internal view returns (uint256) {
        uint256 period = ((block.timestamp - initialAuctionTime) / SECONDS_IN_FOUR_YEARS) + 1;
        uint256 timeElapsed = (block.timestamp - initialAuctionTime) % SECONDS_IN_FOUR_YEARS;
        uint256 auctionableAmount = totalAuctionableAmount >> period;
        return (auctionableAmount * timeElapsed) / SECONDS_IN_FOUR_YEARS;
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

    function _setAuctionGroup(uint256 startTime, uint256 settleTime, uint256 interval) internal {
        AuctionGroup memory auctionGroup;
        auctionGroup.startTime = startTime;
        auctionGroup.settleTime = settleTime;
        auctionGroup.interval = interval;
        auctionGroups.push(auctionGroup);
        emit AuctionGroupSet(currentAuctionGroupId(), startTime, settleTime, interval);
    }

    function revertIfAuctionBiddingInProgress() internal view {
        AuctionGroup memory auctionGroup = auctionGroups[currentAuctionGroupId()];
        if (block.timestamp >= auctionGroup.startTime) {
            unchecked {
                // Overflow not possible: previously checked
                uint256 elapsed = (block.timestamp - auctionGroup.startTime) % auctionGroup.interval;
                // Overflow not possible: auctionInterval > auctionSettleTime
                if (elapsed < auctionGroup.interval - auctionGroup.settleTime) {
                    revert AuctionBiddingInProgress();
                }
            }
        }
    }

    receive() external payable {
        revert AuctionNoDirectTransfer();
    }
}
