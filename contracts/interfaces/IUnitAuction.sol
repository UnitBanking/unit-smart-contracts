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
     * ================ CORE FUNCTIONALITY ================
     */

    function sellUnit(uint256 unitAmount) external;

    function quoteSellUnit(
        uint256 desiredUnitAmount
    ) external returns (uint256 possibleUnitAmount, uint256 collateralAmount);

    function getMaxSellAmount() external returns (uint256 maxUnitAmount, uint256 collateralAmount);

    function getCurrentSellPrice() external returns (uint256 currentSellPrice);

    function buyUnit(uint256 collateralAmount) external;

    function quoteBuyUnit(uint256 collateralAmount) external returns (uint256 unitAmount);
}
