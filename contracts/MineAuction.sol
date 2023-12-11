// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './interfaces/IAuction.sol';
import './interfaces/IERC20.sol';
import './abstracts/Ownable.sol';
import 'hardhat/console.sol';
import './abstracts/Proxiable.sol';
import './abstracts/Mintable.sol';

contract MineAuction is Ownable, IAuction, Proxiable {
    uint8 public constant MINIMUM_AUCTION_INTERVAL = 12;
    address public constant bondingCurve = 0x0f0f0F0f0f0F0F0f0F0F0F0F0F0F0f0f0F0F0F0F;
    Mintable public constant mine = Mintable(0x0f0f0F0f0f0F0F0f0F0F0F0F0F0F0f0f0F0F0F0F);
    IERC20 public constant bidToken = IERC20(0x0f0f0F0f0f0F0F0f0F0F0F0F0F0F0f0f0F0F0F0F);

    uint256 public override auctionStartTime;
    uint256 public override auctionSettleTime;
    uint256 public override auctionInterval;
    uint256 public override nextAuctionId;

    mapping(uint256 auctionId => Auction auction) public auctions;

    function initialize() public virtual override {
        _setOwner(msg.sender);
        super.initialize();
    }

    function setAuctionStartTime(uint256 startTime) external override onlyOwner {
        if (startTime == auctionStartTime || startTime < block.timestamp) {
            revert AuctionSameValueAlreadySet();
        }
        _setAuctionStartTime(startTime);
    }

    function setAuctionSettleTime(uint256 settleTime) external override onlyOwner {
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
        if (interval < MINIMUM_AUCTION_INTERVAL || interval <= auctionSettleTime) {
            revert AuctionInvalidInterval(interval);
        }
        if (interval == auctionInterval) {
            revert AuctionSameValueAlreadySet();
        }
        auctionInterval = interval;
        emit AuctionIntervalSet(interval);
    }

    function bid(uint256 amount) external payable override {
        if (amount == 0) {
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
            _setAuctionStartTime(block.timestamp);
            auctions[nextAuctionId++].targetAmount = getTargetAmount();
        }

        uint256 auctionId = nextAuctionId - 1;
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

    receive() external payable {
        revert AuctionNoDirectTransfer();
    }
}
