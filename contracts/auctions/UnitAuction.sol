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
     * @notice Static (i.e. does not update storage) version of {refreshState}.
     * @return reserveRatio Current UNIT protocol reserve ratio.
     * @return _auctionState Current auction state.
     */
    function refreshStateInMemory() public view returns (uint256 reserveRatio, AuctionState memory _auctionState) {
        reserveRatio = bondingCurve.getReserveRatio();
        _auctionState = auctionState;

        if (inContractionRange(reserveRatio)) {
            if (_auctionState.variant == AUCTION_VARIANT_CONTRACTION) {
                if (block.timestamp - _auctionState.startTime > contractionAuctionMaxDuration) {
                    _auctionState = _getNewContractionAuction();
                }
            } else {
                _auctionState = _getNewContractionAuction();
            }
        } else if (inExpansionRange(reserveRatio)) {
            if (_auctionState.variant == AUCTION_VARIANT_EXPANSION) {
                if (block.timestamp - _auctionState.startTime > expansionAuctionMaxDuration) {
                    _auctionState = _getNewExpansionAuction();
                }
            } else {
                _auctionState = _getNewExpansionAuction();
            }
        } else if (_auctionState.variant != AUCTION_VARIANT_NONE) {
            _auctionState = _getNullAuction();
        }
    }

    /**
     * @inheritdoc IUnitAuction
     */
    function sellUnit(uint256 unitAmount) external {
        (uint256 reserveRatioBefore, AuctionState memory _auctionState) = refreshState();
        if (_auctionState.variant != AUCTION_VARIANT_CONTRACTION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatioBefore);
        }

        uint256 currentPrice = _getCurrentSellPrice(_auctionState.startPrice, _auctionState.startTime);

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

        emit UnitSold(msg.sender, unitAmount, collateralAmount);
    }

    /**
     * @inheritdoc IUnitAuction
     */
    function getMaxSellAmount() external view returns (uint256 maxUnitAmount, uint256 collateralAmount) {
        (uint256 reserveRatio, AuctionState memory _auctionState) = refreshStateInMemory();
        if (_auctionState.variant != AUCTION_VARIANT_CONTRACTION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatio);
        }

        return _getMaxSellAmount(_getCurrentSellPrice(_auctionState.startPrice, _auctionState.startTime));
    }

    /**
     * @inheritdoc IUnitAuction
     */
    function getCurrentSellPrice() external view returns (uint256 currentSellPrice) {
        (uint256 reserveRatio, AuctionState memory _auctionState) = refreshStateInMemory();
        if (_auctionState.variant != AUCTION_VARIANT_CONTRACTION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatio);
        }

        return _getCurrentSellPrice(_auctionState.startPrice, _auctionState.startTime);
    }

    /**
     * @inheritdoc IUnitAuction
     */
    function quoteSellUnit(
        uint256 desiredSellAmount
    ) external view returns (uint256 possibleSellAmount, uint256 collateralAmount) {
        (uint256 reserveRatio, AuctionState memory _auctionState) = refreshStateInMemory();
        if (_auctionState.variant != AUCTION_VARIANT_CONTRACTION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatio);
        }

        (possibleSellAmount, collateralAmount) = _getPossibleSellAmount(
            desiredSellAmount,
            _getCurrentSellPrice(_auctionState.startPrice, _auctionState.startTime)
        );
    }

    /**
     * @inheritdoc IUnitAuction
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

        uint256 currentPrice = _getCurrentBuyPrice(_auctionState.startPrice, _auctionState.startTime);

        uint256 burnPrice = bondingCurve.getBurnPrice();
        if (currentPrice < burnPrice) {
            revert UnitAuctionPriceLowerThanBurnPrice(currentPrice, burnPrice);
        }
        uint256 unitAmount = (collateralAmount * UNITUSD_PRICE_PRECISION) / currentPrice;

        unitToken.mint(msg.sender, unitAmount);

        uint256 reserveRatioAfter = bondingCurve.getReserveRatio();
        if (reserveRatioAfter >= reserveRatioBefore) {
            revert UnitAuctionReserveRatioNotDecreased();
        }
        if (reserveRatioAfter < ReserveRatio.TARGET_RR) {
            revert UnitAuctionResultingReserveRatioOutOfRange(reserveRatioAfter);
        }

        emit UnitBought(msg.sender, unitAmount, collateralAmount);
    }

    /**
     * @inheritdoc IUnitAuction
     */
    function quoteBuyUnit(uint256 collateralAmount) external view returns (uint256 unitAmount) {
        (uint256 reserveRatio, AuctionState memory _auctionState) = refreshStateInMemory();
        if (_auctionState.variant != AUCTION_VARIANT_EXPANSION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatio);
        }

        uint256 currentPrice = _getCurrentBuyPrice(_auctionState.startPrice, _auctionState.startTime);

        uint256 burnPrice = bondingCurve.getBurnPrice();
        if (currentPrice < burnPrice) {
            revert UnitAuctionPriceLowerThanBurnPrice(currentPrice, burnPrice);
        }
        unitAmount = (collateralAmount * currentPrice) / UNITUSD_PRICE_PRECISION;
    }

    /**
     * ================ INTERNAL & PRIVATE FUNCTIONS ================
     */

    function _getCurrentSellPrice(
        uint256 startPrice,
        uint256 startTime
    ) internal view returns (uint256 currentSellPrice) {
        currentSellPrice =
            (startPrice *
                unwrap(
                    pow(
                        wrap(CONTRACTION_PRICE_DECAY_BASE),
                        wrap(((block.timestamp - startTime) * uUNIT) / CONTRACTION_PRICE_DECAY_TIME_INTERVAL)
                    )
                )) /
            uUNIT;
    }

    function _getMaxSellAmount(
        uint256 unitCollateralPrice
    ) internal view returns (uint256 maxSellAmount, uint256 collateralAmount) {
        maxSellAmount = bondingCurve.quoteUnitBurnAmountForHighRR(unitCollateralPrice);
        collateralAmount = _quoteSellUnit(maxSellAmount, unitCollateralPrice);
    }

    function _quoteSellUnit(
        uint256 unitAmount,
        uint256 unitCollateralPrice
    ) internal view returns (uint256 collateralAmount) {
        collateralAmount = (unitAmount * unitCollateralPrice) / UNITUSD_PRICE_PRECISION;
    }

    /**
     * @notice Returns the {desiredSellAmount} or the maximum possible UNIT amount that can be sold for collateral
     * token, whichever is smaller. Used in a UNIT contraction auction scenario.
     * @dev All relevant checks, e.g. whether we are in a contraction auction, must be performed before calling this.
     * @param desiredSellAmount UNIT amount the caller wishes to sell in the auction.
     * @param unitCollateralPrice UNIT price in collateral token to be used in the quote (normally current auction
     * price).
     * @return possibleSellAmount The UNIT amount that can be currently sold.
     * @return collateralAmount The collateral that will be bought for {possibleSellAmount}.
     */
    function _getPossibleSellAmount(
        uint256 desiredSellAmount,
        uint256 unitCollateralPrice
    ) internal view returns (uint256 possibleSellAmount, uint256 collateralAmount) {
        (uint256 maxSellAmount, uint256 maxCollateralAmount) = _getMaxSellAmount(unitCollateralPrice);

        if (desiredSellAmount < maxSellAmount) {
            possibleSellAmount = desiredSellAmount;
            collateralAmount = _quoteSellUnit(desiredSellAmount, unitCollateralPrice);
        } else {
            possibleSellAmount = maxSellAmount;
            collateralAmount = maxCollateralAmount;
        }
    }

    function _getCurrentBuyPrice(
        uint256 startPrice,
        uint256 startTime
    ) internal view returns (uint256 currentBuyPrice) {
        currentBuyPrice =
            (startPrice *
                unwrap(
                    pow(
                        wrap(EXPANSION_PRICE_DECAY_BASE),
                        wrap(((block.timestamp - startTime) * uUNIT) / EXPANSION_PRICE_DECAY_TIME_INTERVAL)
                    )
                )) /
            uUNIT;
    }

    function _getNewContractionAuction() internal view returns (AuctionState memory _auctionState) {
        _auctionState = AuctionState(
            uint32(block.timestamp),
            uint216(
                (bondingCurve.getMintPrice() * contractionStartPriceBuffer) / CONTRACTION_START_PRICE_BUFFER_PRECISION
            ),
            AUCTION_VARIANT_CONTRACTION
        );
    }

    function _startContractionAuction() internal returns (AuctionState memory _auctionState) {
        _auctionState = _getNewContractionAuction();
        auctionState = _auctionState;

        emit AuctionStarted(AUCTION_VARIANT_CONTRACTION, _auctionState.startTime, _auctionState.startPrice);
    }

    function _getNewExpansionAuction() internal view returns (AuctionState memory _auctionState) {
        _auctionState = AuctionState(
            uint32(block.timestamp),
            uint216(bondingCurve.getMintPrice()),
            AUCTION_VARIANT_EXPANSION
        );
    }

    function _startExpansionAuction() internal returns (AuctionState memory _auctionState) {
        _auctionState = _getNewExpansionAuction();
        auctionState = _auctionState;

        emit AuctionStarted(AUCTION_VARIANT_EXPANSION, _auctionState.startTime, _auctionState.startPrice);
    }

    function _getNullAuction() internal pure returns (AuctionState memory _auctionState) {
        _auctionState = AuctionState(0, 0, AUCTION_VARIANT_NONE);
    }

    function _terminateAuction() internal returns (AuctionState memory _auctionState) {
        _auctionState = _getNullAuction();
        auctionState = _auctionState;

        emit AuctionTerminated();
    }

    function inContractionRange(uint256 reserveRatio) internal pure returns (bool) {
        return reserveRatio > ReserveRatio.CRITICAL_RR && reserveRatio <= ReserveRatio.LOW_RR;
    }

    function inExpansionRange(uint256 reserveRatio) internal pure returns (bool) {
        return reserveRatio > ReserveRatio.TARGET_RR;
    }
}
