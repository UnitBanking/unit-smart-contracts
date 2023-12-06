// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './interfaces/IAuction.sol';
import './interfaces/IERC20.sol';
import './abstracts/Ownable.sol';
import 'hardhat/console.sol';

contract MineAuction is Ownable, IAuction {
    uint8 public constant MINIMUM_AUCTION_INTERVAL = 12;
    //TODO: need bonding curve address?
    IERC20 public constant mine = IERC20(0x0f0f0F0f0f0F0F0f0F0F0F0F0F0F0f0f0F0F0F0F);

    uint256 public override auctionStartTime;
    uint256 public override auctionSettleTime;
    uint256 public override auctionInterval;
    uint256 public override nextAuctionId;

    mapping(uint256 auctionId => Auction auction) public auctions;

    constructor() {
        _setOwner(msg.sender);
    }

    function setAuctionStartTime(uint256 startTime) external override onlyOwner {
        if (startTime == auctionStartTime) {
            revert AuctionSameValueAlreadySet();
        }
        auctionStartTime = startTime;
        emit AuctionStartTimeSet(startTime);
    }

    function setAuctionSettleTime(uint256 settleTime) external override onlyOwner {
        //TODO: need to check auctionInterval is set prior to settleTime
        if (auctionInterval - settleTime <= MINIMUM_AUCTION_INTERVAL) {
            revert AuctionInvalidSettleTime(settleTime);
        }
        if (settleTime == auctionSettleTime) {
            revert AuctionSameValueAlreadySet();
        }
        auctionSettleTime = settleTime;
        emit AuctionSettleTimeSet(settleTime);
    }

    function setAuctionInterval(uint256 interval) external override onlyOwner {
        if (interval < MINIMUM_AUCTION_INTERVAL) {
            revert AuctionInvalidInterval(interval);
        }
        if (interval == auctionInterval) {
            revert AuctionSameValueAlreadySet();
        }
        auctionInterval = interval;
        emit AuctionIntervalSet(interval);
    }

    function bid() external payable override {
        if (msg.value == 0) {
            revert AuctionInvalidBidAmount();
        }
        if (block.timestamp < auctionStartTime) {
            revert AuctionNotStarted();
        }
        uint256 auctionElapsed = block.timestamp - auctionStartTime;
        uint256 auctionDuration = auctionInterval - auctionSettleTime;
        if (auctionElapsed >= auctionDuration && auctionElapsed < auctionInterval) {
            revert AuctionInSettlement();
        }

        if (auctionElapsed < auctionDuration) {
            emit AuctionStarted(nextAuctionId, block.timestamp, auctionSettleTime, auctionInterval);
            auctionStartTime = block.timestamp;
            auctions[nextAuctionId++].targetAmount = getTargetAmount();
        }

        uint256 auctionId = nextAuctionId - 1;
        auctions[auctionId].ethAmount += msg.value;
        auctions[auctionId].bid[msg.sender] = msg.value;

        //TODO: transfer eth to bonding curve
        emit AuctionBid(auctionId, msg.sender, msg.value);
    }

    function claim(uint256 _auctionId, uint256 amount) external override {
        _claim(msg.sender, msg.sender, _auctionId, amount);
    }

    function claimTo(address recipient, uint256 _auctionId, uint256 amount) external override {
        _claim(msg.sender, recipient, _auctionId, amount);
    }

    function _claim(address bidder, address recipient, uint256 _auctionId, uint256 amount) internal {
        uint256 claimable = getClaimableAmount(_auctionId, bidder);
        //TODO: handle claimable is 0
        if (amount > claimable) {
            amount = claimable;
        }
        //TODO: transfer from bonding curve
        mine.transferFrom(0x0f0f0F0f0f0F0F0f0F0F0F0F0F0F0f0f0F0F0F0F, recipient, amount);
        auctions[_auctionId].claimed[bidder] += amount;
        emit AuctionClaimed(_auctionId, bidder, amount);
    }

    function getTargetAmount() internal pure returns (uint256) {
        return 100;
    }

    function getClaimableAmount(uint256 _auctionId, address bidder) internal view returns (uint256) {
        if (auctions[_auctionId].ethAmount == 0) {
            return 0;
        }
        //TODO: use prb-math
        uint256 totalClaimable = (auctions[_auctionId].bid[bidder] * auctions[_auctionId].targetAmount) /
            auctions[_auctionId].ethAmount;
        return totalClaimable - auctions[_auctionId].claimed[bidder];
    }

    receive() external payable {
        revert AuctionNoDirectTransfer();
    }
}
