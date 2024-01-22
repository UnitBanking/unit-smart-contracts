// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IUnitAuction {
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

    function buyUnit(uint256 collateralAmount) external;
}
