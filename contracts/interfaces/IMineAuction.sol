// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IMineAuction {
    event AuctionBid(uint256 auctionGroupId, uint256 auctionId, address bidder, uint256 amount);
    event AuctionClaimed(uint256 auctionGroupId, uint256 auctionId, address recipient, uint256 amount);
    event AuctionGroupSet(uint256 groupId, uint256 startTime, uint256 settleTime, uint256 interval);

    error AuctionNoDirectTransfer();
    error AuctionAuctionGroupIdTooLarge(uint256 auctionGroupId);
    error AuctionNotCurrentAuctionId(uint256 auctionId);
    error AuctionStartTimeInThePast();
    error AuctionInvalidInterval(uint256 interval);
    error AuctionInvalidSettleTime(uint256 settleTime);
    error AuctionInvalidBidAmount();
    error AuctionInProgress();
    error AuctionBiddingInProgress();
    error AuctionInSettlement();
    error AuctionClaimingCurrentAuction();

    struct Auction {
        uint256 totalBidAmount;
        uint256 rewardAmount;
        mapping(address bidder => uint256 bidAmount) bid;
        mapping(address bidder => uint256 claimedAmount) claimed;
    }

    struct AuctionGroup {
        uint256 startTime;
        uint256 settleTime;
        uint256 interval;
    }

    function getAuctionGroup(
        uint256 auctionGroupId
    ) external view returns (uint256 startTime, uint256 settleTime, uint256 interval);

    function getCurrentAuctionGroup() external view returns (uint256 startTime, uint256 settleTime, uint256 interval);

    function getAuction(
        uint256 auctionGroupId,
        uint256 auctionId
    ) external view returns (uint256 totalBidAmount, uint256 rewardAmount);

    function getBid(
        uint256 auctionGroupId,
        uint256 auctionId,
        address bidder
    ) external view returns (uint256 bidAmount);

    function getClaimed(
        uint256 auctionGroupId,
        uint256 auctionId,
        address bidder
    ) external view returns (uint256 claimedAmount);

    function currentAuctionGroupId() external view returns (uint256);

    function setAuctionGroup(uint256 startTime, uint256 settleTime, uint256 interval) external;

    function bid(uint256 auctionId, uint256 amount) external;

    function claim(uint256 auctionGroupId, uint256 auctionId, uint256 amount) external;

    function claimTo(uint256 auctionGroupId, uint256 auctionId, address to, uint256 amount) external;
}
