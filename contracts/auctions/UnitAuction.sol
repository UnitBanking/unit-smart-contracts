// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../abstracts/Proxiable.sol';
import '../abstracts/Ownable.sol';
import '../abstracts/ReentrancyGuard.sol';
import '../interfaces/IUnitAuction.sol';
import '../interfaces/IBondingCurve.sol';
import '../libraries/TransferUtils.sol';
import '../libraries/ReserveRatio.sol';
import '../UnitToken.sol';
import { pow, uUNIT, unwrap, wrap } from '@prb/math/src/UD60x18.sol';

/*
TODO:
- Consider putting remaining constants we pull from the bonding curve (like UNITUSD_PRICE_PRECISION) in a common library
- AuctionState struct packing: casting timestamp to uint32 gives us until y2106, the next possible size is uint40, which will last until y36812
- Consider adding a receiver address as an input param to the bid functions, to enable bid exeution on behalf of someone else (as opposed to only for msg.sender)
- Comparative gas tests with a simpler auction price formula (avoiding `refreshState()` calls)
- Add amount in max/amount out min in bid calls
*/

/**
 * @dev IMPORTANT: This contract implements a proxy pattern. Do not modify inheritance list in this contract.
 * Adding, removing, changing or rearranging these base contracts can result in a storage collision after a contract upgrade.
 */
contract UnitAuction is IUnitAuction, Proxiable, Ownable {
    /**
     * ================ CONSTANTS ================
     */

    uint256 public constant CONTRACTION_START_PRICE_BUFFER = 11_000; // 1.1 or 110%
    uint256 public constant CONTRACTION_START_PRICE_BUFFER_PRECISION = 10_000;

    uint256 public constant CONTRACTION_PRICE_DECAY_BASE = 990000000000000000; // 0.99 in prb-math.UNIT precision
    uint256 public constant CONTRACTION_PRICE_DECAY_TIME_INTERVAL = 90 seconds;
    uint256 public constant EXPANSION_PRICE_DECAY_BASE = 999000000000000000; // 0.999 in prb-math.UNIT precision
    uint256 public constant EXPANSION_PRICE_DECAY_TIME_INTERVAL = 1800 seconds;

    uint256 public immutable UNITUSD_PRICE_PRECISION; // All UNIT prices provided by the bonding curve are in this precision

    IBondingCurve public immutable bondingCurve;
    IERC20 public immutable collateralToken;
    UnitToken public immutable unitToken;

    uint8 public constant AUCTION_VARIANT_NONE = 1;
    uint8 public constant AUCTION_VARIANT_CONTRACTION = 2;
    uint8 public constant AUCTION_VARIANT_EXPANSION = 3;

    struct AuctionState {
        uint32 startTime;
        uint216 startPrice;
        uint8 variant;
    }

    /**
     * ================ STATE VARIABLES ================
     */

    /**
     * IMPORTANT:
     * !STORAGE COLLISION WARNING!
     * Adding, removing or rearranging undermentioned state variables can result in a storage collision after a contract
     * upgrade. Any new state variables must be added beneath these to prevent storage conflicts.
     */

    AuctionState public auctionState;

    uint256 public contractionAuctionMaxDuration;
    uint256 public expansionAuctionMaxDuration;
    uint256 public contractionStartPriceBuffer;

    /**
     * IMPORTANT:
     * !STORAGE COLLISION WARNING!
     * Adding, removing or rearranging above state variables can result in a storage collision after a contract upgrade.
     * Any new state variables must be added beneath these to prevent storage conflicts.
     */

    /**
     * ================ CONSTRUCTOR ================
     */

    /**
     * @notice This contract employs a proxy pattern, so the main purpose of the constructor is to render the
     * implementation contract unusable. It initializes certain immutables to optimize gas usage when accessing these
     * variables. Primarily, it calls `super.initialize()` to ensure the contract cannot be initialized with valid
     * values for the remaining variables.
     * @dev This contract must be deployed after the bonding curve has been deployed and initialized via its proxy.
     */
    constructor(IBondingCurve _bondingCurve, UnitToken _unitToken) {
        bondingCurve = _bondingCurve;
        collateralToken = _bondingCurve.collateralToken();
        unitToken = _unitToken;

        UNITUSD_PRICE_PRECISION = _bondingCurve.UNITUSD_PRICE_PRECISION();

        super.initialize();
    }

    /**
     * ================ EXTERNAL & PUBLIC FUNCTIONS ================
     */

    function initialize() public override {
        _setOwner(msg.sender);
        contractionAuctionMaxDuration = 2 hours;
        expansionAuctionMaxDuration = 23 hours;
        contractionStartPriceBuffer = CONTRACTION_START_PRICE_BUFFER;

        auctionState.variant = AUCTION_VARIANT_NONE;

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
     * @notice Sets `expansionAuctionMaxDuration`.
     * @param _maxDuration New max duration of a Unit expansion auction.
     */
    function setExpansionAuctionMaxDuration(uint256 _maxDuration) external onlyOwner {
        expansionAuctionMaxDuration = _maxDuration;
    }

    /**
     * @notice Sets `startPriceBuffer`.
     * @param _startPriceBuffer Must be in `START_PRICE_BUFFER_PRECISION` precision.
     */
    function setStartPriceBuffer(uint256 _startPriceBuffer) external onlyOwner {
        contractionStartPriceBuffer = _startPriceBuffer;
    }

    /**
     * @notice Updates the auction state in storage and returns a copy of it in memory.
     * @return reserveRatio Current UNIT reserve ratio.
     * @return _auctionState Current auction state.
     */
    function refreshState() public returns (uint256 reserveRatio, AuctionState memory _auctionState) {
        reserveRatio = bondingCurve.getReserveRatio();
        _auctionState = auctionState;

        if (inContractionRange(reserveRatio)) {
            if (_auctionState.variant == AUCTION_VARIANT_CONTRACTION) {
                if (block.timestamp - _auctionState.startTime > contractionAuctionMaxDuration) {
                    _auctionState = _startContractionAuction();
                }
            } else {
                _auctionState = _startContractionAuction();
            }
        } else if (inExpansionRange(reserveRatio)) {
            if (_auctionState.variant == AUCTION_VARIANT_EXPANSION) {
                if (block.timestamp - _auctionState.startTime > expansionAuctionMaxDuration) {
                    _auctionState = _startExpansionAuction();
                }
            } else {
                _auctionState = _startExpansionAuction();
            }
        } else if (_auctionState.variant != AUCTION_VARIANT_NONE) {
            _auctionState = _terminateAuction();
        }
    }

    /**
     * @notice Bids in the UNIT contraction auction.
     * @dev If changing the collateral token to an untrusted one (e.g. with unexpected side effects),
     * consider using the `nonReentrant` modifier to prevent potential reentrancy attacks.
     * @param unitAmount Unit token amount to be sold for collateral token.
     */
    function sellUnit(uint256 unitAmount) external {
        (uint256 reserveRatioBefore, AuctionState memory _auctionState) = refreshState();
        if (_auctionState.variant != AUCTION_VARIANT_CONTRACTION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatioBefore);
        }

        uint256 currentPrice = (_auctionState.startPrice *
            unwrap(
                pow(
                    wrap(CONTRACTION_PRICE_DECAY_BASE),
                    wrap(((block.timestamp - _auctionState.startTime) * uUNIT) / CONTRACTION_PRICE_DECAY_TIME_INTERVAL)
                )
            )) / uUNIT;

        uint256 collateralAmount = (unitAmount * currentPrice) / UNITUSD_PRICE_PRECISION;

        unitToken.burnFrom(msg.sender, unitAmount);
        bondingCurve.transferCollateralToken(msg.sender, collateralAmount);

        uint256 reserveRatioAfter = bondingCurve.getReserveRatio();
        if (reserveRatioAfter <= reserveRatioBefore) {
            revert UnitAuctionReserveRatioNotIncreased();
        }
        if (reserveRatioAfter >= ReserveRatio.HIGH_RR) {
            revert UnitAuctionResultingReserveRatioOutOfRange(reserveRatioAfter);
        }

        emit SellUnit(msg.sender, unitAmount, collateralAmount);
    }

    /**
     * @notice Bids in the UNIT expansion auction.
     * @dev If changing the collateral token to an untrusted one (e.g. with unexpected side effects),
     * consider using the `nonReentrant` modifier to prevent potential reentrancy attacks.
     * @param collateralAmount Collateral token amount to be sold for UNIT token.
     */
    function buyUnit(uint256 collateralAmount) external {
        (uint256 reserveRatioBefore, AuctionState memory _auctionState) = refreshState();
        if (_auctionState.variant != AUCTION_VARIANT_EXPANSION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatioBefore);
        }

        collateralAmount = TransferUtils.safeTransferFrom(
            collateralToken,
            msg.sender,
            address(bondingCurve),
            collateralAmount
        );

        uint256 currentPrice = (_auctionState.startPrice *
            unwrap(
                pow(
                    wrap(EXPANSION_PRICE_DECAY_BASE),
                    wrap(((block.timestamp - _auctionState.startTime) * uUNIT) / EXPANSION_PRICE_DECAY_TIME_INTERVAL)
                )
            )) / uUNIT;

        uint256 burnPrice = bondingCurve.getBurnPrice();
        if (currentPrice < burnPrice) {
            revert UnitAuctionPriceLowerThanBurnPrice(currentPrice, burnPrice);
        }
        uint256 unitAmount = (collateralAmount * currentPrice) / UNITUSD_PRICE_PRECISION;

        unitToken.mint(msg.sender, unitAmount);

        uint256 reserveRatioAfter = bondingCurve.getReserveRatio();
        if (reserveRatioAfter >= reserveRatioBefore) {
            revert UnitAuctionReserveRatioNotDecreased();
        }
        if (reserveRatioAfter < ReserveRatio.TARGET_RR) {
            revert UnitAuctionResultingReserveRatioOutOfRange(reserveRatioAfter);
        }

        emit BuyUnit(msg.sender, unitAmount, collateralAmount);
    }

    /**
     * ================ INTERNAL & PRIVATE FUNCTIONS ================
     */

    function _startContractionAuction() internal returns (AuctionState memory _auctionState) {
        _auctionState = AuctionState(
            uint32(block.timestamp), // TODO: Confirm we want to do this
            uint216(
                (bondingCurve.getMintPrice() * contractionStartPriceBuffer) / CONTRACTION_START_PRICE_BUFFER_PRECISION
            ),
            AUCTION_VARIANT_CONTRACTION
        );
        auctionState = _auctionState;

        emit StartAuction(AUCTION_VARIANT_CONTRACTION, _auctionState.startTime, _auctionState.startPrice);
    }

    function _startExpansionAuction() internal returns (AuctionState memory _auctionState) {
        _auctionState = AuctionState(
            uint32(block.timestamp),
            uint216(bondingCurve.getMintPrice()),
            AUCTION_VARIANT_EXPANSION
        );
        auctionState = _auctionState;

        emit StartAuction(AUCTION_VARIANT_EXPANSION, _auctionState.startTime, _auctionState.startPrice);
    }

    function _terminateAuction() internal returns (AuctionState memory _auctionState) {
        _auctionState = AuctionState(0, 0, AUCTION_VARIANT_NONE);
        auctionState = _auctionState;

        emit TerminateAuction();
    }

    function inContractionRange(uint256 reserveRatio) internal pure returns (bool) {
        return reserveRatio > ReserveRatio.CRITICAL_RR && reserveRatio <= ReserveRatio.LOW_RR;
    }

    function inExpansionRange(uint256 reserveRatio) internal pure returns (bool) {
        return reserveRatio > ReserveRatio.TARGET_RR;
    }
}
