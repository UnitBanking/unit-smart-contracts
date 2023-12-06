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
    error AuctionInvalidInterval(uint256 interval);
    error AuctionInvalidSettleTime(uint256 settleTime);
    error AuctionSameValueAlreadySet();
    error AuctionInvalidBidAmount();
    error AuctionInSettlement();
    error AuctionNotStarted();

    struct Auction {
        uint256 ethAmount;
        uint256 targetAmount;
        mapping(address bidder => uint256 ethAmount) bid;
        mapping(address bidder => uint256 claimedAmount) claimed;
    }

    //TODO: add mapping auctions reader interface?

    function auctionStartTime() external view returns (uint256);

    function auctionSettleTime() external view returns (uint256);

    function auctionInterval() external view returns (uint256);

    function nextAuctionId() external view returns (uint256);

    function setAuctionStartTime(uint256 startTime) external;

    function setAuctionSettleTime(uint256 settleTime) external;

    function setAuctionInterval(uint256 interval) external;

    function bid() external payable;

    function claim(uint256 _auctionId, uint256 amount) external;

    function claimTo(address recipient, uint256 _auctionId, uint256 amount) external;
}
