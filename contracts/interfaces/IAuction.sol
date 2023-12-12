// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IAuction {
    event AuctionStartTimeSet(uint256 startTime);
    event AuctionSettleTimeSet(uint256 settleTime);
    event AuctionIntervalSet(uint256 interval);
    event AuctionStarted(uint256 newAuctionId, uint256 startTime, uint256 settleTime, uint256 interval);
    event AuctionBid(uint256 auctionId, address bidder, uint256 amount);
    event AuctionClaimed(uint256 auctionId, address recipient, uint256 amount);

    error AuctionNoDirectTransfer();
    error AuctionStartTimeInThePast();
    error AuctionInvalidInterval(uint256 interval);
    error AuctionInvalidSettleTime(uint256 settleTime);
    error AuctionSameValueAlreadySet();
    error AuctionInvalidBidAmount();
    error AuctionNotStarted();
    error AuctionInProgress();
    error AuctionNotInSettlement();
    error AuctionInSettlement();

    struct Auction {
        uint256 totalBidAmount;
        uint256 targetAmount;
        mapping(address bidder => uint256 bidAmount) bid;
        mapping(address bidder => uint256 claimedAmount) claimed;
    }

    function getAuction(uint256 auctionId) external view returns (uint256 totalBidAmount, uint256 targetAmount);

    function getBid(uint256 auctionId, address bidder) external view returns (uint256 bidAmount);

    function getClaimed(uint256 auctionId, address bidder) external view returns (uint256 claimedAmount);

    function auctionStartTime() external view returns (uint256);

    function auctionSettleTime() external view returns (uint256);

    function auctionInterval() external view returns (uint256);

    function nextAuctionId() external view returns (uint256);

    function setAuctionStartTime(uint256 startTime) external;

    function setAuctionSettleTime(uint256 settleTime) external;

    function setAuctionInterval(uint256 interval) external;

    function bid(uint256 amount) external payable;

    function claim(uint256 auctionId, uint256 amount) external;

    function claimTo(address recipient, uint256 auctionId, uint256 amount) external;
}
