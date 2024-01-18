// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import '../abstracts/Proxiable.sol';
import '../abstracts/Ownable.sol';
import '../libraries/TransferUtils.sol';
import '../BondingCurve.sol';
import '../UnitToken.sol';
import '../interfaces/IUnitAuction.sol';

/*
TODO:
- AuctionState struct packing to be confirmed
- add event logging
- !IMPORTANT! gas tests
*/

contract UnitAuction is IUnitAuction, Proxiable, Ownable {
    using TransferUtils for address;

    uint256 public constant CRITICAL_RR = 1;
    uint256 public constant LOW_RR = 3;
    uint256 public constant TARGET_RR = 5;

    uint256 public constant START_PRICE_BUFFER = 11_000; // 1.1 or 110% TODO: This is TBC
    uint256 public constant START_PRICE_BUFFER_PRECISION = 10_000;

    BondingCurve public immutable bondingCurve;
    UnitToken public immutable unitToken;

    uint256 public contractionAuctionMaxDuration;
    uint256 public expansionAuctionMaxDuration;
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

        super.initialize();
    }

    /**
     * ================ EXTERNAL & PUBLIC FUNCTIONS ================
     */

    function initialize() public override {
        _setOwner(msg.sender);
        contractionAuctionMaxDuration = 2 hours;
        expansionAuctionMaxDuration = 23 hours;
        startPriceBuffer = START_PRICE_BUFFER;

        super.initialize();
    }

    /**
     * @notice Sets `contractionAuctionMaxDuration`.
     * @param _maxDuration New max duration of a Unit contraction auction.
     */
    function setContractionAuctionMaxDuration(uint256 _maxDuration) external onlyOwner {
        contractionAuctionMaxDuration = _maxDuration;
    }

    /**
     * @notice Sets `contractionAuctionMaxDuration`.
     * @param _maxDuration New max duration of a Unit contraction auction.
     */
    function setExpansionAuctionMaxDuration(uint256 _maxDuration) external onlyOwner {
        expansionAuctionMaxDuration = _maxDuration;
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
     * @return reserveRatio Current UNIT reserve ratio.
     * @return _auctionState Current auction state.
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
            } else if (block.timestamp - _auctionState.startTime > contractionAuctionMaxDuration) {
                _auctionState = _startContractionAuction();
            }
        } else if (_auctionState.variant == AUCTION_VARIANT_EXPANSION) {
            if (!inExpansionRange(reserveRatio)) {
                if (inContractionRange(reserveRatio)) {
                    _auctionState = _startContractionAuction();
                } else {
                    _auctionState = _terminateAuction();
                }
            } else if (block.timestamp - _auctionState.startTime > expansionAuctionMaxDuration) {
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
        uint256 collateralAmount = unitAmount * currentPrice; // TODO: Double check precision here

        unitToken.burnFrom(msg.sender, unitAmount);
        TransferUtils.safeTransferFrom(
            bondingCurve.collateralToken(),
            address(bondingCurve),
            msg.sender,
            collateralAmount
        );

        uint256 reserveRatioAfter = bondingCurve.getReserveRatio();
        if (reserveRatioAfter <= reserveRatioBefore) {
            revert UnitAuctionReserveRatioNotIncreased();
        }
        if (inExpansionRange(reserveRatioAfter)) {
            revert UnitAuctionResultingReserveRatioOutOfRange(reserveRatioAfter);
        }
    }

    /**
     * @notice Bids in the UNIT expansion auction.
     * @param collateralAmount Collateral token amount to be sold for UNIT token.
     */
    function buyUnit(uint256 collateralAmount) external {
        (uint256 reserveRatioBefore, AuctionState memory _auctionState) = refreshState();
        if (_auctionState.variant != AUCTION_VARIANT_EXPANSION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatioBefore);
        }

        collateralAmount = TransferUtils.safeTransferFrom(
            bondingCurve.collateralToken(),
            msg.sender,
            address(bondingCurve),
            collateralAmount
        );

        uint256 currentPrice = (_auctionState.startPrice *
            999 ** ((block.timestamp - _auctionState.startTime) / 1800 seconds)) / 1000;
        uint256 burnPrice = bondingCurve.getBurnPrice();
        if (currentPrice < burnPrice) {
            revert UnitAuctionPriceLowerThanBurnPrice(currentPrice, burnPrice);
        }
        uint256 unitAmount = collateralAmount * currentPrice; // TODO: Double check precision here

        unitToken.mint(msg.sender, unitAmount);

        uint256 reserveRatioAfter = bondingCurve.getReserveRatio();
        if (reserveRatioAfter <= reserveRatioBefore) {
            revert UnitAuctionReserveRatioNotIncreased();
        }
        if (!inExpansionRange(reserveRatioAfter)) {
            revert UnitAuctionResultingReserveRatioOutOfRange(reserveRatioAfter);
        }
    }

    /**
     * ================ INTERNAL & PRIVATE FUNCTIONS ================
     */

    function _startContractionAuction() internal returns (AuctionState memory _auctionState) {
        _auctionState = AuctionState(
            uint32(block.timestamp), // TODO: Confirm we want to do this
            uint216((bondingCurve.getMintPrice() * startPriceBuffer) / START_PRICE_BUFFER_PRECISION),
            AUCTION_VARIANT_CONTRACTION
        );
        auctionState = _auctionState;
    }

    function _startExpansionAuction() internal returns (AuctionState memory _auctionState) {
        _auctionState = AuctionState(
            uint32(block.timestamp),
            uint216(bondingCurve.getMintPrice()),
            AUCTION_VARIANT_EXPANSION
        );
        auctionState = _auctionState;
    }

    function _terminateAuction() internal returns (AuctionState memory _auctionState) {
        _auctionState = AuctionState(0, 0, AUCTION_VARIANT_NONE);
        auctionState = _auctionState;
    }

    function inContractionRange(uint256 reserveRatio) internal pure returns (bool) {
        return reserveRatio > CRITICAL_RR && reserveRatio <= LOW_RR;
    }

    function inExpansionRange(uint256 reserveRatio) internal pure returns (bool) {
        return reserveRatio > TARGET_RR;
    }
}
