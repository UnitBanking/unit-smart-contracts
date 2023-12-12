// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './interfaces/IAuction.sol';
import './interfaces/IERC20.sol';
import './abstracts/Ownable.sol';
import './abstracts/Proxiable.sol';
import './abstracts/Mintable.sol';
import './abstracts/Lockable.sol';

contract MineAuction is Ownable, Proxiable, IAuction, Lockable {
    uint8 public constant MINIMUM_AUCTION_INTERVAL = 12;
    address public constant bondingCurve = 0x0f0f0F0f0f0F0F0f0F0F0F0F0F0F0f0f0F0F0F0F;
    Mintable public constant mine = Mintable(0x0f0f0F0f0f0F0F0f0F0F0F0F0F0F0f0f0F0F0F0F);
    IERC20 public constant bidToken = IERC20(0x0f0f0F0f0f0F0F0f0F0F0F0F0F0F0f0f0F0F0F0F);

    uint256 public override auctionStartTime;
    uint256 public override auctionSettleTime;
    uint256 public override auctionInterval;
    uint256 public override nextAuctionId;

    mapping(uint256 auctionId => Auction auction) private auctions;

    function initialize() public virtual override {
        _setOwner(msg.sender);
        //TODO: either initialize times here or check in bid() interval/settle != 0
        _setAuctionInterval(24 hours);
        _setAuctionSettleTime(1 hours);
        super.initialize();
    }

    function setAuctionStartTime(uint256 startTime) external override onlyOwner lock {
        revertIfInSettlement();
        if (startTime == auctionStartTime) {
            revert AuctionSameValueAlreadySet();
        }
        if (startTime <= auctionStartTime + auctionInterval) {
            revert AuctionStartTimeInThePast();
        }
        _setAuctionStartTime(startTime);
    }

    function setAuctionSettleTime(uint256 settleTime) external override onlyOwner lock {
        _setAuctionSettleTime(settleTime);
    }

    function setAuctionInterval(uint256 interval) external override onlyOwner lock {
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

    function bid(uint256 amount) external payable override lock {
        if (amount == 0) {
            revert AuctionInvalidBidAmount();
        }
        if (block.timestamp < auctionStartTime) {
            revert AuctionNotStarted();
        }
        uint256 auctionElapsed;
        unchecked {
            // Overflow not possible: previous checked block.timestamp >= auctionStartTime
            auctionElapsed = block.timestamp - auctionStartTime;
            // Overflow not possible: auctionInterval > auctionSettleTime
            if (auctionElapsed > auctionInterval - auctionSettleTime && auctionElapsed <= auctionInterval) {
                revert AuctionInSettlement();
            }
        }

        if (auctionElapsed > auctionInterval) {
            emit AuctionStarted(nextAuctionId, block.timestamp, auctionSettleTime, auctionInterval);
            _setAuctionStartTime(block.timestamp);
            auctions[nextAuctionId++].targetAmount = getTargetAmount();
        }

        uint256 auctionId = nextAuctionId - 1;
        auctions[auctionId].totalBidAmount += amount;
        auctions[auctionId].bid[msg.sender] = amount;

        //TODO: transfer bid token to bonding curve
        //bidToken.transferFrom(msg.sender, bondingCurve, amount);
        emit AuctionBid(auctionId, msg.sender, amount);
    }

    function claim(uint256 auctionId, uint256 amount) external override {
        _claim(msg.sender, msg.sender, auctionId, amount);
    }

    function claimTo(address recipient, uint256 auctionId, uint256 amount) external override {
        _claim(msg.sender, recipient, auctionId, amount);
    }

    function _claim(address bidder, address recipient, uint256 auctionId, uint256 amount) internal lock {
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

    //TODO: stub for testing
    function getTargetAmount() internal pure returns (uint256) {
        return 100;
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
        revertIfInSettlement();
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
        revertIfInSettlement();
        if (interval < MINIMUM_AUCTION_INTERVAL || interval <= auctionSettleTime) {
            revert AuctionInvalidInterval(interval);
        }
        if (interval == auctionInterval) {
            revert AuctionSameValueAlreadySet();
        }
        auctionInterval = interval;
        emit AuctionIntervalSet(interval);
    }

    function revertIfInSettlement() internal view {
        unchecked {
            // Overflow not possible: auctionInterval > auctionSettleTime
            if (block.timestamp <= auctionStartTime + auctionInterval - auctionSettleTime) {
                revert AuctionNotInSettlement();
            }
        }
    }

    receive() external payable {
        revert AuctionNoDirectTransfer();
    }
}
