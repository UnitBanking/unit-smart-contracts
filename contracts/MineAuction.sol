// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './interfaces/IMineAuction.sol';
import './interfaces/IERC20.sol';
import './abstracts/Ownable.sol';
import './abstracts/Proxiable.sol';
import './MineToken.sol';
import './abstracts/Pausable.sol';
import './libraries/TransferUtils.sol';

/// @title MineAuction contract for auctioning MINE tokens
/// @notice You can use this contract to auction MINE tokens
/// @dev The contract is proxiable and pauseable
contract MineAuction is Ownable, IMineAuction, Proxiable, Pausable {
    uint256 constant SECONDS_IN_YEAR = 365 * 24 * 60 * 60;
    uint256 constant SECONDS_IN_FOUR_YEARS = 4 * SECONDS_IN_YEAR;
    uint256 constant AUCTIONABLE_NUMERATOR = 8000;
    uint256 constant AUCTIONABLE_DENOMINATOR = 10000;

    BondingCurve public immutable bondingCurve;
    MineToken public immutable mine;
    IERC20 public immutable bidToken;

    AuctionGroup[] private auctionGroups;
    mapping(uint256 auctionGroupId => mapping(uint256 auctionId => Auction auction)) auctions;

    uint256 public totalAuctionableAmount;
    uint256 public initialAuctionTime;

    constructor(BondingCurve _bondingCurve, MineToken _mine, IERC20 _bidToken) {
        initialized = true;
        bondingCurve = _bondingCurve;
        mine = _mine;
        bidToken = _bidToken;
    }

    /// @notice Initialize the contract, set the owner, and set the initial auction time, and set the first auction group
    /// @param _initialAuctionTime The initial auction time, used to calculate the reward amount, since it is half each four years
    /// @dev This function can only be called once
    function initialize(uint256 _initialAuctionTime) external {
        _setOwner(msg.sender);
        _setAuctionGroup(0, 1 hours, 23 hours);
        initialAuctionTime = _initialAuctionTime;
        totalAuctionableAmount = (mine.MAX_SUPPLY() * AUCTIONABLE_NUMERATOR) / AUCTIONABLE_DENOMINATOR;

        super.initialize();
    }

    /// @notice Append the auction group, each time when  the auction settleTime or bitTime should be changed,
    /// a new auction group should be appended, then when time passed the startTime of the new group, the new group
    /// will be the current group, and thus all the auction after that will be in the new group, and use the new group's
    /// settleTime and bidTime
    /// @param startTime The start time of the new auction group, like tomorrow 12:00
    /// @param settleTime The settle time of the new auction group, like 1 hour
    /// @param bidTime The bid time of the new auction group, like 23 hours
    function setAuctionGroup(uint64 startTime, uint32 settleTime, uint32 bidTime) external override onlyOwner {
        AuctionGroup memory lastAuctionGroup = auctionGroups[auctionGroups.length - 1];
        uint256 auctionStartTime = lastAuctionGroup.startTime;
        // has no future group
        if (block.timestamp >= lastAuctionGroup.startTime) {
            unchecked {
                // Underflow not possible: previously checked
                uint256 elapsed = (block.timestamp - lastAuctionGroup.startTime) %
                    (lastAuctionGroup.bidTime + lastAuctionGroup.settleTime);
                auctionStartTime = block.timestamp - elapsed;
            }
        }

        if (auctionStartTime + lastAuctionGroup.bidTime > startTime) {
            revert MineAuctionStartTimeTooEarly();
        }
        _setAuctionGroup(startTime, settleTime, bidTime);
    }

    /// @notice Get the auction group by the auction group id
    /// @param auctionGroupId The auction group id, like 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    /// @return startTime The start time of the auction group
    /// @return settleTime The settle time of the auction group
    /// @return bidTime The bid time of the auction group
    function getAuctionGroup(
        uint256 auctionGroupId
    ) external view override returns (uint256 startTime, uint256 settleTime, uint256 bidTime) {
        revertIfAuctionGroupIdOutOfBounds(auctionGroupId);
        AuctionGroup memory auctionGroup = auctionGroups[auctionGroupId];
        startTime = auctionGroup.startTime;
        settleTime = auctionGroup.settleTime;
        bidTime = auctionGroup.bidTime;
    }

    /// @notice Get the current auction group, the current auction group is the one that has the start time
    /// less than or equal to the current time
    /// @return auctionGroupId The auction group id of the current auction group
    /// @return startTime The start time of the current auction group
    /// @return settleTime The settle time of the current auction group
    /// @return bidTime The bid time of the current auction group
    /// @dev since auction group is appended, the current auction group is the last one that has
    function getCurrentAuctionGroup()
        external
        view
        override
        returns (uint256 auctionGroupId, uint256 startTime, uint256 settleTime, uint256 bidTime)
    {
        auctionGroupId = auctionGroups.length - 1;
        for (; auctionGroupId >= 0; auctionGroupId--) {
            if (auctionGroups[auctionGroupId].startTime <= block.timestamp) {
                break;
            }
        }
        AuctionGroup memory auctionGroup = auctionGroups[auctionGroupId];
        startTime = auctionGroup.startTime;
        settleTime = auctionGroup.settleTime;
        bidTime = auctionGroup.bidTime;
    }

    /// @notice Get the total auction group count
    function getAuctionGroupCount() external view override returns (uint256) {
        return auctionGroups.length;
    }

    /// @notice Get the auction info by the auction group id and auction id
    /// @param auctionGroupId The auction group id, like 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    /// @param auctionId The auction id, like 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    function getAuction(
        uint256 auctionGroupId,
        uint256 auctionId
    ) external view override returns (uint256 totalBidAmount, uint256 rewardAmount) {
        revertIfAuctionGroupIdOutOfBounds(auctionGroupId);
        revertIfAuctionIdInFuture(auctionGroupId, auctionId);
        Auction storage auction = auctions[auctionGroupId][auctionId];
        totalBidAmount = auction.totalBidAmount;
        rewardAmount = auction.rewardAmount;
    }

    /// @notice Get the bid amount token by the auction group id, auction id and bidder
    /// @param auctionGroupId The auction group id, like 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    /// @param auctionId The auction id, like 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    /// @param bidder The bidder's address
    /// @dev since the auction group is appended, the auction group id is the index of the auction in the auction group
    /// since auction id is the index of the auction in the auction group based on time, so it could be not continuous
    function getBid(
        uint256 auctionGroupId,
        uint256 auctionId,
        address bidder
    ) external view override returns (uint256 bidAmount) {
        revertIfAuctionGroupIdOutOfBounds(auctionGroupId);
        revertIfAuctionIdInFuture(auctionGroupId, auctionId);
        bidAmount = auctions[auctionGroupId][auctionId].bid[bidder];
    }

    /// @notice Get the claimed amount token by the auction group id, auction id and bidder
    /// @dev it will revert if the auction group id is out of bounds, or the auction id is in future
    function getClaimed(
        uint256 auctionGroupId,
        uint256 auctionId,
        address bidder
    ) external view override returns (uint256 claimedAmount) {
        revertIfAuctionGroupIdOutOfBounds(auctionGroupId);
        revertIfAuctionIdInFuture(auctionGroupId, auctionId);
        claimedAmount = auctions[auctionGroupId][auctionId].claimed[bidder];
    }

    /// @notice Get the auction info by the auction group id, auction id and bidder
    /// @dev it will revert if the auction group id is out of bounds, or the auction id is in future
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
        revertIfAuctionGroupIdOutOfBounds(auctionGroupId);
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

    /// @notice Bid the auction by the auction group id, auction id and amount
    /// @param auctionGroupId The auction group id, like 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    /// @param auctionId The auction id, like 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    /// @param amount The amount of the bid token
    /// @dev  both the group id and auction is are passed from the client, so the client should calculate the auction group id and auction id
    /// we validate the auction group id and auction id, and then calculate the start time and end time of the auction,
    /// and then validate  current time is in the middle of a auction, it should not be during a settlement, and it should
    /// not be the future or past auction
    function bid(uint256 auctionGroupId, uint256 auctionId, uint256 amount) external override onlyNotPaused {
        if (amount == 0) {
            revert MineAuctionInvalidBidAmount();
        }
        revertIfAuctionGroupIdOutOfBounds(auctionGroupId);

        AuctionGroup memory auctionGroup = auctionGroups[auctionGroupId];
        if (block.timestamp < auctionGroup.startTime) {
            revert MineAuctionNotCurrentAuctionGroupId(auctionGroupId);
        } else if (auctionGroups.length > auctionGroupId + 1) {
            AuctionGroup memory nextAuctionGroup = auctionGroups[auctionGroupId + 1];
            if (block.timestamp >= nextAuctionGroup.startTime) {
                revert MineAuctionNotCurrentAuctionGroupId(auctionGroupId);
            }
            uint256 elapsed = (block.timestamp - auctionGroup.startTime) %
                (auctionGroup.bidTime + auctionGroup.settleTime);
            uint256 currentAuctionStartTime = block.timestamp - elapsed;
            if (nextAuctionGroup.startTime - currentAuctionStartTime < auctionGroup.bidTime) {
                revert MineAuctionCurrentAuctionDisabled();
            }
        }

        uint256 startTime = auctionId * (auctionGroup.bidTime + auctionGroup.settleTime) + auctionGroup.startTime;
        uint256 endTime = startTime + auctionGroup.bidTime;
        if (block.timestamp < startTime || block.timestamp >= endTime) {
            revert MineAuctionNotCurrentAuctionId(auctionId);
        }

        if (auctions[auctionGroupId][auctionId].rewardAmount == 0) {
            auctions[auctionGroupId][auctionId].rewardAmount = getRewardAmount(auctionGroupId);
        }

        uint256 transferAmount = TransferUtils.safeTransferFrom(bidToken, msg.sender, address(bondingCurve), amount);
        auctions[auctionGroupId][auctionId].totalBidAmount += transferAmount;
        auctions[auctionGroupId][auctionId].bid[msg.sender] += transferAmount;
        emit AuctionBid(auctionGroupId, auctionId, msg.sender, transferAmount);
    }

    /// @notice Claim the amount of token by the auction group id, auction id and amount
    function claim(uint256 auctionGroupId, uint256 auctionId, uint256 amount) external override {
        _claim(auctionGroupId, auctionId, msg.sender, msg.sender, amount);
    }

    /// @notice Claim the amount of token by the auction group id, auction id and amount
    function claimTo(uint256 auctionGroupId, uint256 auctionId, address to, uint256 amount) external override {
        _claim(auctionGroupId, auctionId, msg.sender, to, amount);
    }

    /// @dev make sure the auction group id is not out of bounds
    function revertIfAuctionGroupIdOutOfBounds(uint256 auctionGroupId) internal view {
        if (auctionGroupId >= auctionGroups.length) {
            revert MineAuctionInvalidAuctionGroupId(auctionGroupId);
        }
    }

    /// @dev auction info should only be available for past auction, include current auction
    function revertIfAuctionIdInFuture(uint256 auctionGroupId, uint256 auctionId) internal view {
        AuctionGroup memory auctionGroup = auctionGroups[auctionGroupId];
        if (block.timestamp < auctionGroup.startTime) {
            revert MineAuctionAuctionGroupIdInFuture(auctionGroupId);
        }

        if (block.timestamp < auctionGroup.startTime + auctionId * (auctionGroup.bidTime + auctionGroup.settleTime)) {
            revert MineAuctionAuctionIdInFuture(auctionId);
        }
    }

    /// @dev claim is only enabled for past auction, exclude current auction
    function revertIfAuctionIdInFutureOrCurrent(uint256 auctionGroupId, uint256 auctionId) internal view {
        AuctionGroup memory auctionGroup = auctionGroups[auctionGroupId];
        if (block.timestamp < auctionGroup.startTime) {
            revert MineAuctionAuctionGroupIdInFuture(auctionGroupId);
        }

        if (
            block.timestamp <
            auctionGroup.startTime + (auctionId + 1) * (auctionGroup.bidTime + auctionGroup.settleTime)
        ) {
            revert MineAuctionAuctionIdInFutureOrCurrent(auctionId);
        }
    }

    function _claim(uint256 auctionGroupId, uint256 auctionId, address bidder, address to, uint256 amount) internal {
        revertIfAuctionGroupIdOutOfBounds(auctionGroupId);
        revertIfAuctionIdInFutureOrCurrent(auctionGroupId, auctionId);
        uint256 claimable = getClaimableAmount(auctionGroupId, auctionId, bidder);
        if (amount > claimable) {
            revert MineAuctionInsufficientClaimAmount(amount);
        }
        auctions[auctionGroupId][auctionId].claimed[bidder] += amount;
        mine.mint(to, amount);
        emit AuctionClaimed(auctionGroupId, auctionId, bidder, amount);
    }

    //TODO: use prb math to optimize
    /// @dev Get the reward amount token by the auction group id, it will revert if the auction group id is out of bounds
    /// half each four years, and it distributed to the auction group based on the auction group's bidTime and settleTime
    function getRewardAmount(uint256 auctionGroupId) internal view returns (uint256) {
        AuctionGroup memory auctionGroup = auctionGroups[auctionGroupId];
        uint256 elapsed = block.timestamp - initialAuctionTime;
        uint256 period = (elapsed / SECONDS_IN_FOUR_YEARS) + 1;
        uint256 auctionableAmount = totalAuctionableAmount >> period;
        return (auctionableAmount * (auctionGroup.bidTime + auctionGroup.settleTime)) / SECONDS_IN_FOUR_YEARS;
    }

    /// @dev Get the claimable amount token by the auction group id, auction id and bidder,
    /// it will revert if the auction group id is out of bounds, or the auction id is in future
    ///  bidToken *  ( rewardAmount / totalBidAmount ) - claimed
    function getClaimableAmount(
        uint256 auctionGroupId,
        uint256 auctionId,
        address bidder
    ) internal view returns (uint256) {
        if (auctions[auctionGroupId][auctionId].totalBidAmount == 0) {
            return 0;
        }
        Auction storage auction = auctions[auctionGroupId][auctionId];
        //TODO: use prb-math?
        uint256 totalClaimable = (auction.bid[bidder] * auction.rewardAmount) / auction.totalBidAmount;
        return totalClaimable - auction.claimed[bidder];
    }

    function _setAuctionGroup(uint64 startTime, uint32 settleTime, uint32 bidTime) internal {
        AuctionGroup memory auctionGroup;
        auctionGroup.startTime = startTime;
        auctionGroup.settleTime = settleTime;
        auctionGroup.bidTime = bidTime;
        auctionGroups.push(auctionGroup);
        emit AuctionGroupSet(auctionGroups.length - 1, startTime, settleTime, bidTime);
    }

    receive() external payable {
        revert MineAuctionNoDirectTransfer();
    }
}
