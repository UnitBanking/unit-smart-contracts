// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import '../abstracts/Proxiable.sol';
import '../abstracts/Ownable.sol';
import '../libraries/TransferHelper.sol';
import '../BondingCurve.sol';
import '../UnitToken.sol';

contract UnitAuction is Proxiable, Ownable {
    using TransferHelper for address;
    error UnitAuctionRRTooHigh();
    error UnitAuctionRRNotIncreased();
    error UnitAuctionTerminated();
    error UnitAuctionNoDirectTransfers();

    uint256 public constant CRITICAL_RR = 1;
    uint256 public constant LOW_RR = 3;

    uint256 public constant START_PRICE_BUFFER_PRECISION = 100;

    BondingCurve public immutable bondingCurve;
    UnitToken public immutable unitToken;

    uint256 public auctionMaxDuration;
    uint256 public auctionStartTime;
    uint256 public startPrice;
    uint256 public startPriceBuffer;

    /**
     * ================ CONSTRUCTOR ================
     */

    /**
     * @notice This contract uses a Proxy pattern.
     * Locks the contract, to prevent the implementation contract from being used.
     */
    constructor(BondingCurve _bondingCurve, UnitToken _unitToken) {
        bondingCurve = _bondingCurve;
        unitToken = _unitToken;

        initialized = true;
    }

    /**
     * ================ EXTERNAL & PUBLIC FUNCTIONS ================
     */

    receive() external payable {
        revert UnitAuctionNoDirectTransfers();
    }

    function initialize() public override {
        _setOwner(msg.sender);
        auctionMaxDuration = 2 hours;
        super.initialize();
    }

    /**
     * @notice Sets `auctionMaxDuration`.
     * @param _auctionMaxDuration New max duration of Unit auction.
     */
    function setAuctionMaxDuration(uint256 _auctionMaxDuration) external onlyOwner {
        auctionMaxDuration = _auctionMaxDuration;
    }

    /**
     * @notice Sets `startPriceBuffer`.
     * @param _startPriceBuffer Must be in `START_PRICE_BUFFER_PRECISION` precision.
     */
    function setStartPriceBuffer(uint256 _startPriceBuffer) external onlyOwner {
        startPriceBuffer = _startPriceBuffer;
    }

    /**
     * @notice Bids in the UNIT contraction auction.
     * @param unitAmount Unit token amount to be sold for collateral token
     */
    function sellUnit(uint256 unitAmount) external {
        uint256 reserveRatioBefore = bondingCurve.getReserveRatio();
        // Check beforeRR
        if (reserveRatioBefore > LOW_RR) {
            revert UnitAuctionRRTooHigh();
        }
        if (block.timestamp - auctionStartTime > auctionMaxDuration) {
            revert UnitAuctionTerminated();
        }

        uint256 currentPrice = (auctionStartTime * 99 ** ((block.timestamp - auctionStartTime) / 90 seconds)) / 100;
        uint256 collateralAmount = unitAmount * currentPrice;

        unitToken.burnFrom(msg.sender, unitAmount);
        msg.sender.transferEth(collateralAmount); // TODO: change to collateral ERC20 token

        uint256 reserveRatioAfter = bondingCurve.getReserveRatio();
        // Check afterRR
        if (reserveRatioAfter > bondingCurve.HIGH_RR()) {
            revert UnitAuctionRRTooHigh();
        }
        // Check if afterRR > beforeRR
        if (reserveRatioAfter <= reserveRatioBefore) {
            revert UnitAuctionRRNotIncreased();
        }
    }

    function buyUnit(uint256 collateralAmount) external {}

    /**
     * ================ INTERNAL FUNCTIONS ================
     */

    function _initializeAuction() internal {
        startPrice = bondingCurve.getMintPrice() * startPriceBuffer / START_PRICE_BUFFER_PRECISION;
        auctionStartTime = block.timestamp;
    }

    function _terminateAuction() internal {
        auctionStartTime = 0;        
    }
}
