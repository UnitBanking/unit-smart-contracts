// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './interfaces/IAuction.sol';
import './interfaces/IERC20.sol';
import './abstracts/Ownable.sol';
import './abstracts/Proxiable.sol';
import './MineToken.sol';

contract MineAuction is Ownable, Proxiable, IAuction {
    uint8 public constant MINIMUM_AUCTION_INTERVAL = 12;
    uint256 constant SECONDS_IN_YEAR = 365 * 24 * 60 * 60;
    uint256 constant SECONDS_IN_FOUR_YEARS = 4 * SECONDS_IN_YEAR;

    address public bondingCurve;
    MineToken public mine;
    IERC20 public bidToken;

    uint256 public override auctionStartTime;
    uint256 public override auctionSettleTime;
    uint256 public override auctionInterval;
    uint256 public override nextAuctionId = 1;

    uint256 public totalAuctionableAmount;
    uint256 public initialAuctionaTime;

    mapping(uint256 auctionId => Auction auction) private auctions;

    function initialize() public virtual override {
        _setOwner(msg.sender);
        _setAuctionStartTime(566352000); // 00:00
        //TODO: either initialize times here or check in bid() interval/settle != 0
        _setAuctionInterval(24 hours);
        _setAuctionSettleTime(1 hours);
        nextAuctionId = 1;
        super.initialize();
    }

    //TODO: use setter temp, should replace with precompile in the future
    function setBondingCurve(address _bondingCurve) external onlyOwner {
        bondingCurve = _bondingCurve;
    }

    function setMine(address _mine) external onlyOwner {
        mine = MineToken(_mine);
        //Todo:  use prb math
        totalAuctionableAmount = (mine.MAX_SUPPLY() * 80) / 100;
    }

    function setBidToken(address _bidToken) external onlyOwner {
        bidToken = IERC20(_bidToken);
    }

    function setAuctionStartTime(uint256 startTime) external override onlyOwner {
        revertIfNotInSettlement();
        if (startTime % auctionInterval == auctionStartTime % auctionInterval) {
            revert AuctionSameValueAlreadySet();
        }
        if (startTime < block.timestamp) {
            revert AuctionStartTimeInThePast();
        }

        _setAuctionStartTime(startTime);
        nextAuctionId++;
    }

    function setAuctionSettleTime(uint256 settleTime) external override onlyOwner {
        _setAuctionSettleTime(settleTime);
    }

    function setAuctionInterval(uint256 interval) external override onlyOwner {
        _setAuctionInterval(interval);
    }

    function getAuction(
        uint256 auctionId
    ) external view override returns (uint256 totalBidAmount, uint256 targetAmount) {
        totalBidAmount = auctions[auctionId].totalBidAmount;
        targetAmount = auctions[auctionId].targetAmount;
    }

    function getBid(uint256 auctionId, address bidder) external view override returns (uint256 bidAmount) {
        bidAmount = auctions[auctionId].bid[bidder];
    }

    function getClaimed(uint256 auctionId, address bidder) external view override returns (uint256 claimedAmount) {
        claimedAmount = auctions[auctionId].claimed[bidder];
    }

    function bid(uint256 amount) external override {
        if (amount == 0) {
            revert AuctionInvalidBidAmount();
        }
        if (block.timestamp < auctionStartTime) {
            revert AuctionNotStarted();
        }
        uint256 auctionElapsed;
        uint256 auctionDuration;
        uint256 auctionId;
        unchecked {
            // Overflow not possible: previous checked block.timestamp >= auctionStartTime
            auctionElapsed = block.timestamp - auctionStartTime;
            // Overflow not possible: auctionInterval > auctionSettleTime
            auctionDuration = auctionInterval - auctionSettleTime;
            if (auctionElapsed > auctionDuration && auctionElapsed <= auctionInterval) {
                revert AuctionInSettlement();
            }
            // Overflow not possible: nextAuctionId >= 1
            auctionId = nextAuctionId - 1;
        }

        if (auctionElapsed < auctionDuration && auctions[auctionId].totalBidAmount == 0) {
            initializeAuction(auctionId);
        } else if (auctionElapsed > auctionInterval) {
            if (auctions[auctionId].totalBidAmount == 0) {
                initializeAuction(auctionId);
            } else {
                nextAuctionId++;
                auctionId = nextAuctionId - 1;
                initializeAuction(auctionId);
            }
            _setAuctionStartTime(block.timestamp - (auctionElapsed % auctionInterval));
        }

        auctions[auctionId].totalBidAmount += amount;
        auctions[auctionId].bid[msg.sender] = amount;

        bidToken.transferFrom(msg.sender, bondingCurve, amount);
        emit AuctionBid(auctionId, msg.sender, amount);
    }

    function claim(uint256 auctionId, uint256 amount) external override {
        _claim(msg.sender, msg.sender, auctionId, amount);
    }

    function claimTo(address recipient, uint256 auctionId, uint256 amount) external override {
        _claim(msg.sender, recipient, auctionId, amount);
    }

    function _claim(address bidder, address recipient, uint256 auctionId, uint256 amount) internal {
        uint256 currentAuctionId = nextAuctionId == 0 ? 0 : nextAuctionId - 1;
        if (block.timestamp <= auctionStartTime + auctionInterval && auctionId == currentAuctionId) {
            revert AuctionInProgress();
        }
        uint256 claimable = getClaimableAmount(auctionId, bidder);
        if (amount > claimable) {
            amount = claimable;
        }
        if (amount == 0) {
            return;
        }
        auctions[auctionId].claimed[bidder] += amount;
        mine.mint(recipient, amount);
        emit AuctionClaimed(auctionId, bidder, amount);
    }

    function initializeAuction(uint256 auctionId) internal {
        if (auctionId == 0) {
            initialAuctionaTime = block.timestamp;
        }
        auctions[auctionId].targetAmount = getTargetAmount();
        emit AuctionStarted(auctionId, block.timestamp, auctionSettleTime, auctionInterval);
    }

    //TODO: use prb math to optimize
    function getTargetAmount() internal view returns (uint256) {
        uint256 period = ((block.timestamp - initialAuctionaTime) / SECONDS_IN_FOUR_YEARS) + 1;
        uint256 currentAuctionId = nextAuctionId - 1;
        uint256 auctionableAmount = totalAuctionableAmount;
        uint256 i = 0;
        for (; i < period; i++) {
            auctionableAmount = auctionableAmount / 2;
        }
        return (auctionableAmount * (currentAuctionId + 1)) / 1460;
    }

    function getClaimableAmount(uint256 auctionId, address bidder) internal view returns (uint256) {
        if (auctions[auctionId].totalBidAmount == 0) {
            return 0;
        }
        //TODO: use prb-math
        uint256 totalClaimable = (auctions[auctionId].bid[bidder] * auctions[auctionId].targetAmount) /
            auctions[auctionId].totalBidAmount;
        return totalClaimable - auctions[auctionId].claimed[bidder];
    }

    function _setAuctionStartTime(uint256 startTime) internal {
        auctionStartTime = startTime;
        emit AuctionStartTimeSet(startTime);
    }

    function _setAuctionSettleTime(uint256 settleTime) internal {
        revertIfNotInSettlement();
        if (auctionInterval - settleTime <= MINIMUM_AUCTION_INTERVAL) {
            revert AuctionInvalidSettleTime(settleTime);
        }
        if (settleTime == auctionSettleTime) {
            revert AuctionSameValueAlreadySet();
        }
        auctionSettleTime = settleTime;
        emit AuctionSettleTimeSet(settleTime);
    }

    function _setAuctionInterval(uint256 interval) internal {
        revertIfNotInSettlement();
        if (interval < MINIMUM_AUCTION_INTERVAL || interval <= auctionSettleTime) {
            revert AuctionInvalidInterval(interval);
        }
        if (interval == auctionInterval) {
            revert AuctionSameValueAlreadySet();
        }
        auctionInterval = interval;
        emit AuctionIntervalSet(interval);
    }

    function revertIfNotInSettlement() internal view {
        unchecked {
            // Overflow not possible: auctionInterval > auctionSettleTime
            if (
                block.timestamp < auctionStartTime + auctionInterval - auctionSettleTime &&
                block.timestamp >= auctionStartTime
            ) {
                revert AuctionBiddingInProgress();
            }
        }
    }

    receive() external payable {
        revert AuctionNoDirectTransfer();
    }
}
