// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../abstracts/Proxiable.sol';
import '../abstracts/Ownable.sol';
import '../abstracts/ReentrancyGuard.sol';
import '../interfaces/IUnitAuction.sol';
import '../interfaces/IBondingCurve.sol';
import '../libraries/TransferUtils.sol';
import '../libraries/ProtocolConstants.sol';
import '../libraries/PrecisionUtils.sol';
import '../UnitToken.sol';
import { pow, uUNIT, unwrap, wrap } from '@prb/math/src/UD60x18.sol';

/*
TODO:
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
    using PrecisionUtils for uint256;

    /**
     * ================ CONSTANTS ================
     */

    uint256 public constant CONTRACTION_START_PRICE_BUFFER = 11_000; // 1.1 or 110%
    uint256 public constant CONTRACTION_START_PRICE_BUFFER_PRECISION = 10_000;

    uint256 public constant CONTRACTION_PRICE_DECAY_BASE = 990000000000000000; // 0.99 in prb-math.UNIT precision
    uint256 public constant CONTRACTION_PRICE_DECAY_TIME_INTERVAL = 90 seconds;
    uint256 public constant EXPANSION_PRICE_DECAY_BASE = 999000000000000000; // 0.999 in prb-math.UNIT precision
    uint256 public constant EXPANSION_PRICE_DECAY_TIME_INTERVAL = 1800 seconds;

    uint256 public immutable STANDARD_PRECISION;

    IBondingCurve public immutable bondingCurve;
    IERC20 public immutable collateralToken;
    uint256 private immutable collateralTokenDecimals;
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
        STANDARD_PRECISION = ProtocolConstants.STANDARD_PRECISION;

        bondingCurve = _bondingCurve;
        IERC20 _collateralToken = _bondingCurve.collateralToken();
        collateralToken = _collateralToken;
        collateralTokenDecimals = _collateralToken.decimals();
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
     * @notice Sets `contractionStartPriceBuffer`.
     * @param _startPriceBuffer Must be in `START_PRICE_BUFFER_PRECISION` precision.
     */
    function setStartPriceBuffer(uint256 _startPriceBuffer) external onlyOwner {
        contractionStartPriceBuffer = _startPriceBuffer;
    }

    enum StateChange {
        NoChange,
        ContractionAuctionStarted,
        ExpansionAuctionStarted,
        AuctionTerminated
    }

    /**
     * @notice Updates the auction state in storage and returns a copy of it in memory.
     * @return reserveRatio Current UNIT reserve ratio.
     * @return _auctionState Current auction state.
     */
    function refreshState() public returns (uint256 reserveRatio, AuctionState memory _auctionState) {
        StateChange stateChange;
        (reserveRatio, _auctionState, stateChange) = _computeState();

        if (stateChange == StateChange.ContractionAuctionStarted) {
            auctionState = _auctionState;
            emit AuctionStarted(AUCTION_VARIANT_CONTRACTION, _auctionState.startTime, _auctionState.startPrice);
        } else if (stateChange == StateChange.ExpansionAuctionStarted) {
            auctionState = _auctionState;
            emit AuctionStarted(AUCTION_VARIANT_EXPANSION, _auctionState.startTime, _auctionState.startPrice);
        } else if (stateChange == StateChange.AuctionTerminated) {
            auctionState = _auctionState;
            emit AuctionTerminated();
        }
    }

    /**
     * @notice Static (i.e. does not update storage) version of {refreshState}.
     * @return reserveRatio Current UNIT protocol reserve ratio.
     * @return _auctionState Current auction state.
     */
    function refreshStateInMemory() public view returns (uint256 reserveRatio, AuctionState memory _auctionState) {
        (reserveRatio, _auctionState, ) = _computeState();
    }

    /**
     * @inheritdoc IUnitAuction
     */
    function sellUnit(uint256 unitAmountIn) external {
        (uint256 reserveRatioBefore, AuctionState memory _auctionState) = refreshState();
        if (_auctionState.variant != AUCTION_VARIANT_CONTRACTION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatioBefore);
        }

        uint256 unitCollateralPrice = _getCurrentSellUnitPrice(_auctionState.startPrice, _auctionState.startTime);

        uint256 collateralAmountOut = (unitAmountIn * unitCollateralPrice).fromStandardPrecision(
            collateralTokenDecimals
        ) / STANDARD_PRECISION;

        unitToken.burnFrom(msg.sender, unitAmountIn);
        bondingCurve.transferCollateralToken(msg.sender, collateralAmountOut);

        uint256 reserveRatioAfter = bondingCurve.getReserveRatio();
        if (reserveRatioAfter <= reserveRatioBefore) {
            revert UnitAuctionReserveRatioNotIncreased();
        }
        if (reserveRatioAfter >= ProtocolConstants.HIGH_RR) {
            revert UnitAuctionResultingReserveRatioOutOfRange(reserveRatioAfter);
        }

        emit UnitSold(msg.sender, unitAmountIn, collateralAmountOut);
    }

    /**
     * @inheritdoc IUnitAuction
     */
    function getCurrentSellUnitPrice() external view returns (uint256 currentSellUnitPrice) {
        (uint256 reserveRatio, AuctionState memory _auctionState) = refreshStateInMemory();
        if (_auctionState.variant != AUCTION_VARIANT_CONTRACTION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatio);
        }

        return _getCurrentSellUnitPrice(_auctionState.startPrice, _auctionState.startTime);
    }

    /**
     * @inheritdoc IUnitAuction
     */
    function quoteSellUnit(
        uint256 desiredUnitAmountIn
    ) external view returns (uint256 possibleUnitAmountIn, uint256 collateralAmountOut) {
        (uint256 reserveRatio, AuctionState memory _auctionState) = refreshStateInMemory();
        if (_auctionState.variant != AUCTION_VARIANT_CONTRACTION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatio);
        }

        uint256 unitCollateralPrice = _getCurrentSellUnitPrice(_auctionState.startPrice, _auctionState.startTime);
        (uint256 maxUnitAmountIn, uint256 maxCollateralAmount) = _getMaxSellUnitAmount(unitCollateralPrice);

        if (desiredUnitAmountIn < maxUnitAmountIn) {
            possibleUnitAmountIn = desiredUnitAmountIn;
            collateralAmountOut = _quoteSellUnit(desiredUnitAmountIn, unitCollateralPrice);
        } else {
            possibleUnitAmountIn = maxUnitAmountIn;
            collateralAmountOut = maxCollateralAmount;
        }
    }

    /**
     * @inheritdoc IUnitAuction
     */
    function getMaxSellUnitAmount() external view returns (uint256 maxUnitAmountIn, uint256 collateralAmountOut) {
        (uint256 reserveRatio, AuctionState memory _auctionState) = refreshStateInMemory();
        if (_auctionState.variant != AUCTION_VARIANT_CONTRACTION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatio);
        }

        return _getMaxSellUnitAmount(_getCurrentSellUnitPrice(_auctionState.startPrice, _auctionState.startTime));
    }

    /**
     * @inheritdoc IUnitAuction
     */
    function buyUnit(uint256 collateralAmountIn) external {
        (uint256 reserveRatioBefore, AuctionState memory _auctionState) = refreshState();
        if (_auctionState.variant != AUCTION_VARIANT_EXPANSION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatioBefore);
        }

        collateralAmountIn = TransferUtils.safeTransferFrom(
            collateralToken,
            msg.sender,
            address(bondingCurve),
            collateralAmountIn
        );

        uint256 unitCollateralPrice = _getCurrentBuyUnitPrice(_auctionState.startPrice, _auctionState.startTime);

        uint256 burnPrice = bondingCurve.getBurnPrice();
        if (unitCollateralPrice < burnPrice) {
            revert UnitAuctionPriceLowerThanBurnPrice(unitCollateralPrice, burnPrice);
        }

        uint256 unitAmountOut = (collateralAmountIn * STANDARD_PRECISION).toStandardPrecision(collateralTokenDecimals) /
            unitCollateralPrice;
        unitToken.mint(msg.sender, unitAmountOut);

        uint256 reserveRatioAfter = bondingCurve.getReserveRatio();
        if (reserveRatioAfter >= reserveRatioBefore) {
            revert UnitAuctionReserveRatioNotDecreased();
        }
        if (reserveRatioAfter < ProtocolConstants.TARGET_RR) {
            revert UnitAuctionResultingReserveRatioOutOfRange(reserveRatioAfter);
        }

        emit UnitBought(msg.sender, unitAmountOut, collateralAmountIn);
    }

    /**
     * @inheritdoc IUnitAuction
     */
    function getCurrentBuyUnitPrice() external view returns (uint256 currentBuyUnitPrice) {
        (uint256 reserveRatio, AuctionState memory _auctionState) = refreshStateInMemory();
        if (_auctionState.variant != AUCTION_VARIANT_EXPANSION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatio);
        }

        return _getCurrentBuyUnitPrice(_auctionState.startPrice, _auctionState.startTime);
    }

    /**
     * @inheritdoc IUnitAuction
     */
    function quoteBuyUnit(
        uint256 desiredCollateralAmountIn
    ) external view returns (uint256 possibleCollateralAmountIn, uint256 unitAmountOut) {
        (uint256 reserveRatio, AuctionState memory _auctionState) = refreshStateInMemory();
        if (_auctionState.variant != AUCTION_VARIANT_EXPANSION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatio);
        }

        uint256 unitCollateralPrice = _getCurrentBuyUnitPrice(_auctionState.startPrice, _auctionState.startTime);

        uint256 burnUnitPrice = bondingCurve.getBurnPrice();
        if (unitCollateralPrice < burnUnitPrice) {
            revert UnitAuctionPriceLowerThanBurnPrice(unitCollateralPrice, burnUnitPrice);
        }

        (uint256 maxCollateralAmountIn, uint256 maxUnitAmountOut) = _getMaxBuyUnitAmount(unitCollateralPrice);

        if (desiredCollateralAmountIn < maxCollateralAmountIn) {
            possibleCollateralAmountIn = desiredCollateralAmountIn;
            unitAmountOut = _quoteBuyUnit(desiredCollateralAmountIn, unitCollateralPrice);
        } else {
            possibleCollateralAmountIn = maxCollateralAmountIn;
            unitAmountOut = maxUnitAmountOut;
        }
    }

    /**
     * @inheritdoc IUnitAuction
     */
    function getMaxBuyUnitAmount() external view returns (uint256 maxCollateralAmountIn, uint256 unitAmountOut) {
        (uint256 reserveRatio, AuctionState memory _auctionState) = refreshStateInMemory();
        if (_auctionState.variant != AUCTION_VARIANT_EXPANSION) {
            revert UnitAuctionInitialReserveRatioOutOfRange(reserveRatio);
        }

        return _getMaxBuyUnitAmount(_getCurrentBuyUnitPrice(_auctionState.startPrice, _auctionState.startTime));
    }

    /**
     * ================ INTERNAL & PRIVATE FUNCTIONS ================
     */

    function _computeState()
        internal
        view
        returns (uint256 reserveRatio, AuctionState memory _auctionState, StateChange stateChange)
    {
        reserveRatio = bondingCurve.getReserveRatio();
        _auctionState = auctionState;

        if (inContractionRange(reserveRatio)) {
            if (_auctionState.variant == AUCTION_VARIANT_CONTRACTION) {
                if (block.timestamp - _auctionState.startTime > contractionAuctionMaxDuration) {
                    _auctionState = _getNewContractionAuction();
                    stateChange = StateChange.ContractionAuctionStarted;
                }
            } else {
                _auctionState = _getNewContractionAuction();
                stateChange = StateChange.ContractionAuctionStarted;
            }
        } else if (inExpansionRange(reserveRatio)) {
            if (_auctionState.variant == AUCTION_VARIANT_EXPANSION) {
                if (block.timestamp - _auctionState.startTime > expansionAuctionMaxDuration) {
                    _auctionState = _getNewExpansionAuction();
                    stateChange = StateChange.ExpansionAuctionStarted;
                }
            } else {
                _auctionState = _getNewExpansionAuction();
                stateChange = StateChange.ExpansionAuctionStarted;
            }
        } else if (_auctionState.variant != AUCTION_VARIANT_NONE) {
            _auctionState = _getNullAuction();
            stateChange = StateChange.AuctionTerminated;
        }
    }

    /**
     * ================ SELL UNIT (CONTRACTION AUCTION) ================
     */

    /**
     * @notice Given the auction {startPrice} and {startTime}, returns the current UNIT sell price in a contraction
     * auction.
     * @dev The returned value is in STANDARD_PRECISION.
     */
    function _getCurrentSellUnitPrice(
        uint256 startPrice,
        uint256 startTime
    ) internal view returns (uint256 currentSellUnitPrice) {
        currentSellUnitPrice =
            (startPrice *
                unwrap(
                    pow(
                        wrap(CONTRACTION_PRICE_DECAY_BASE),
                        wrap(((block.timestamp - startTime) * uUNIT) / CONTRACTION_PRICE_DECAY_TIME_INTERVAL)
                    )
                )) /
            uUNIT;
    }

    /**
     * @notice Given the {unitCollateralPrice}, calculates how much collateral token can be bought for {unitAmountIn}.
     * @dev The returned value is in collateral token precision.
     */
    function _quoteSellUnit(
        uint256 unitAmountIn,
        uint256 unitCollateralPrice
    ) internal view returns (uint256 collateralAmountOut) {
        collateralAmountOut =
            (unitAmountIn * unitCollateralPrice).fromStandardPrecision(collateralTokenDecimals) /
            STANDARD_PRECISION;
    }

    function _getMaxSellUnitAmount(
        uint256 unitCollateralPrice
    ) internal view returns (uint256 maxUnitAmountIn, uint256 collateralAmountOut) {
        maxUnitAmountIn = bondingCurve.quoteUnitBurnAmountForHighRR(unitCollateralPrice);
        collateralAmountOut = _quoteSellUnit(maxUnitAmountIn, unitCollateralPrice);
    }

    /**
     * ================ BUY UNIT (EXPANSION AUCTION) ================
     */

    function _getCurrentBuyUnitPrice(
        uint256 startPrice,
        uint256 startTime
    ) internal view returns (uint256 currentBuyUnitPrice) {
        currentBuyUnitPrice =
            (startPrice *
                unwrap(
                    pow(
                        wrap(EXPANSION_PRICE_DECAY_BASE),
                        wrap(((block.timestamp - startTime) * uUNIT) / EXPANSION_PRICE_DECAY_TIME_INTERVAL)
                    )
                )) /
            uUNIT;
    }

    /**
     * @notice Given the {unitCollateralPrice}, calculates how much UNIT can be bought for {collateralAmountIn}.
     * @dev The returned value is in UNIT precision.
     */
    function _quoteBuyUnit(
        uint256 collateralAmountIn,
        uint256 unitCollateralPrice
    ) internal view returns (uint256 unitAmountOut) {
        unitAmountOut =
            (collateralAmountIn * STANDARD_PRECISION).toStandardPrecision(collateralTokenDecimals) /
            unitCollateralPrice;
    }

    function _getMaxBuyUnitAmount(
        uint256 unitCollateralPrice
    ) internal view returns (uint256 maxCollateralAmountIn, uint256 unitAmountOut) {
        maxCollateralAmountIn = bondingCurve.quoteCollateralAmountInForTargetRR(unitCollateralPrice);
        unitAmountOut = _quoteBuyUnit(maxCollateralAmountIn, unitCollateralPrice);
    }

    /**
     * ================ AUCTION STATE ================
     */

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

    /**
     * ================ RESERVE RATIO ================
     */

    function inContractionRange(uint256 reserveRatio) internal pure returns (bool) {
        return reserveRatio > ProtocolConstants.CRITICAL_RR && reserveRatio <= ProtocolConstants.LOW_RR;
    }

    function inExpansionRange(uint256 reserveRatio) internal pure returns (bool) {
        return reserveRatio > ProtocolConstants.TARGET_RR;
    }
}
