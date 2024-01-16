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
     * @dev Reserve ration must increase after completing a bid.
     */
    error UnitAuctionReserveRatioNotIncreased();

    /**
     * ================ CORE FUNCTIONALITY ================
     */

    function sellUnit(uint256 unitAmount) external;

    function buyUnit(uint256 collateralAmount) external;
}
