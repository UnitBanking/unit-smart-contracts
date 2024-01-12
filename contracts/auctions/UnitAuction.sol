// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import '../abstracts/Proxiable.sol';
import '../abstracts/Ownable.sol';
import '../libraries/TransferUtils.sol';
import '../BondingCurve.sol';
import '../UnitToken.sol';

contract UnitAuction is Proxiable, Ownable {
    using TransferUtils for address;
    error UnitAuctionInitialReserveRatioOutOfRange(uint256 reserveRatio);
    error UnitAuctionResultingReserveRatioOutOfRange(uint256 reserveRatio);
    error UnitAuctionReserveRatioNotIncreased();
    error UnitAuctionNoDirectTransfers();

    uint256 public constant CRITICAL_RR = 1;
    uint256 public constant LOW_RR = 3;
    uint256 public constant TARGET_RR = 5;

    uint256 public constant START_PRICE_BUFFER_PRECISION = 100;

    BondingCurve public immutable bondingCurve;
    UnitToken public immutable unitToken;

    uint256 public auctionMaxDuration;
    uint256 public startPriceBuffer;

    /**
     * ================ AUCTION STATE ================
     */

    uint8 public constant AUCTION_VARIANT_NONE = 1;
    uint8 public constant AUCTION_VARIANT_CONTRACTION = 2;
    uint8 public constant AUCTION_VARIANT_EXPANSION = 3;

    struct AuctionState {
        uint32 startTime;
        uint216 startPrice;
        uint8 variant;
    }

    AuctionState public auctionState;

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
     * @notice Updates the auction state in storage and returns a copy of it in memory.
     */
    function refreshState() public returns (uint256 reserveRatio, AuctionState memory _auctionState) {
        reserveRatio = bondingCurve.getReserveRatio();
        _auctionState = auctionState;

        if (_auctionState.variant == AUCTION_VARIANT_CONTRACTION) {
            if (!inContractionRange(reserveRatio)) {
                if (inExpansionRange(reserveRatio)) {
                    _auctionState = _startExpansionAuction();
                } else {
                    _auctionState = _terminateAuction();
                }
            } else if (block.timestamp - _auctionState.startTime > auctionMaxDuration) {
                _auctionState = _startContractionAuction();
            }
        } else if (_auctionState.variant == AUCTION_VARIANT_EXPANSION) {
            if (!inExpansionRange(reserveRatio)) {
                if (inContractionRange(reserveRatio)) {
                    _auctionState = _startContractionAuction();
                } else {
                    _auctionState = _terminateAuction();
                }
            } else if (block.timestamp - _auctionState.startTime > auctionMaxDuration) {
                _auctionState = _startExpansionAuction();
            }
        } else if (inContractionRange(reserveRatio)) {
            _auctionState = _startContractionAuction();
        } else if (inExpansionRange(reserveRatio)) {
            _auctionState = _startExpansionAuction();
        }
    }

    /**
     * @notice Bids in the UNIT contraction auction.
     * @param unitAmount Unit token amount to be sold for collateral token.
     */
    function sellUnit(uint256 unitAmount) external {
        (uint256 reserveRatioBefore, AuctionState memory _auctionState) = refreshState();
        if (_auctionState.variant != AUCTION_VARIANT_CONTRACTION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatioBefore);
        }

        uint256 currentPrice = (_auctionState.startPrice *
            99 ** ((block.timestamp - _auctionState.startTime) / 90 seconds)) / 100;
        uint256 collateralAmount = unitAmount * currentPrice;

        unitToken.burnFrom(msg.sender, unitAmount);
        TransferUtils.safeTransfer(bondingCurve.collateralToken(), msg.sender, collateralAmount);

        uint256 reserveRatioAfter = bondingCurve.getReserveRatio();
        if (reserveRatioAfter > bondingCurve.HIGH_RR()) {
            revert UnitAuctionResultingReserveRatioOutOfRange(reserveRatioAfter);
        }
        if (reserveRatioAfter <= reserveRatioBefore) {
            revert UnitAuctionReserveRatioNotIncreased();
        }
    }

    function buyUnit(uint256 collateralAmount) external {}

    /**
     * ================ INTERNAL & PRIVATE FUNCTIONS ================
     */

    function _startContractionAuction() internal returns (AuctionState memory _auctionState) {
        _auctionState = AuctionState(
            uint32(block.timestamp), // TODO: Confirm we want to do this
            uint216((bondingCurve.getMintPrice() * startPriceBuffer) / START_PRICE_BUFFER_PRECISION), // TODO: Refactor casting here
            AUCTION_VARIANT_CONTRACTION
        );
        auctionState = _auctionState;
    }

    function _startExpansionAuction() internal returns (AuctionState memory _auctionState) {
        _auctionState = AuctionState(
            uint32(block.timestamp),
            0, // TODO: add price formula
            AUCTION_VARIANT_EXPANSION
        );
        auctionState = _auctionState;
    }

    function _terminateAuction() internal returns (AuctionState memory _auctionState) {
        _auctionState = AuctionState(0, 0, AUCTION_VARIANT_NONE);
        auctionState = _auctionState;
    }

    function inContractionRange(uint256 reserveRatio) private pure returns (bool) {
        return reserveRatio > CRITICAL_RR && reserveRatio <= LOW_RR;
    }

    function inExpansionRange(uint256 reserveRatio) private pure returns (bool) {
        return reserveRatio > TARGET_RR;
    }
}
