// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IUnitAuction {
    /**
     * ================ EVENTS ================
     */

    event UnitSold(address sender, uint256 unitAmount, uint256 collateralAmount);
    event UnitBought(address sender, uint256 unitAmount, uint256 collateralAmount);
    event AuctionStarted(uint8 variant, uint32 startTime, uint216 startPrice);
    event AuctionTerminated();

    /**
     * ================ ERRORS ================
     */

    /**
     * @dev Cannot begin a bid due to initial reserve ratio out of range.
     */
    error UnitAuctionInitialReserveRatioOutOfRange(uint256 reserveRatio);

    /**
     * @dev Cannot complete a bid due to resulting reserve ratio out of range.
     */
    error UnitAuctionResultingReserveRatioOutOfRange(uint256 reserveRatio);

    /**
     * @dev Reserve ratio must increase after completing a bid.
     */
    error UnitAuctionReserveRatioNotIncreased();

    /**
     * @dev Reserve ratio must decrease after completing a bid.
     */
    error UnitAuctionReserveRatioNotDecreased();

    /**
     * @dev The current auction price is lower than the UNIT redemption (burn) price.
     */
    error UnitAuctionPriceLowerThanBurnPrice(uint256 currentPrice, uint256 burnPrice);

    /**
     * ================ CONSTANTS ================
     */

    function STANDARD_PRECISION() external view returns (uint256);

    /**
     * ================ CORE FUNCTIONALITY ================
     */

    /**
     * @notice Bids in the UNIT contraction auction.
     * @dev Assumes a non-reentrant and non-rebasing collateral token.
     * TODO: When changing the collateral token to an untrusted one (e.g. with unexpected side effects), consider
     * taking measures to prevent potential reentrancy.
     * @param unitAmountIn Unit token amount to be sold for collateral token.
     */
    function sellUnit(uint256 unitAmountIn) external;

    /**
     * @notice Returns the current UNIT price in collateral token in a contraction auction (if one is active).
     * If no contraction auction is active, the call reverts.
     * @dev The returned value is in STANDARD_PRECISION.
     */
    function getCurrentSellUnitPrice() external returns (uint256 currentSellUnitPrice);

    /**
     * @notice Given the desired UNIT sell amount, calculates the possible sell amount and the corresponding collateral
     * amount that can be bought in a UNIT contraction auction at the moment. If the desired sell amount is greater
     * than the protocol can allow, returns the maximum possible at the moment.
     * If no contraction auction is active, the call reverts.
     * @param desiredUnitAmountIn The UNIT amount the caller wishes to sell in an auction.
     * @return possibleUnitAmountIn The maximum possible UNIT amount that can be currently sold (UNIT precision).
     * @return collateralAmountOut The collateral amount that would be bought for {possibleUnitAmount} (collateral
     * token precision).
     */
    function quoteSellUnit(
        uint256 desiredUnitAmountIn
    ) external returns (uint256 possibleUnitAmountIn, uint256 collateralAmountOut);

    /**
     * @notice Returns the maximum UNIT amount a user can successfully sell in a contraction auction at the moment
     * and the corresponding collateral amount they will receive.
     * If no contraction auction is active, the call reverts.
     * @return maxUnitAmountIn The maximum UNIT amount that will result in a successfull bid in a contraction auction
     * (UNIT precision).
     * @return collateralAmountOut The collateral amount that will be bought in the bid (collateral token precision).
     */
    function getMaxSellUnitAmount() external returns (uint256 maxUnitAmountIn, uint256 collateralAmountOut);

    /**
     * @notice Bids in the UNIT expansion auction.
     * @dev Assumes a non-reentrant and non-rebasing collateral token.
     * TODO: When changing the collateral token to an untrusted one (e.g. with unexpected side effects), consider
     * taking measures to prevent potential reentrancy.
     * @param collateralAmountIn Collateral token amount to be sold for UNIT token.
     */
    function buyUnit(uint256 collateralAmountIn) external;

    /**
     * TODO: This function needs to be refactored to calculate the maximum UNIT token amount that can be bought.
     */
    function quoteBuyUnit(uint256 collateralAmountIn) external returns (uint256 unitAmountOut);
}
