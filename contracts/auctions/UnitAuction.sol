// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import '../abstracts/Proxiable.sol';
import '../libraries/TransferHelper.sol';
import '../BondingCurve.sol';
import '../UnitToken.sol';

contract UnitAuction is Proxiable {
    using TransferHelper for address;
    error UnitAuctionTooHighRR();
    error UnitAuctionRRTooHigh();
    error UnitAuctionTerminated();

    uint256 public constant CRITICAL_RR = 1;
    uint256 public constant LOW_RR = 3;
    uint256 public constant PRICE_BUFFER = 1;

    BondingCurve public immutable bondingCurve;
    UnitToken public immutable unitToken;

    uint256 public auctionMaxDuration = 2 hours;
    uint256 public auctionStartTime;
    uint256 public startPrice;

    constructor(BondingCurve _bondingCurve, UnitToken _unitToken) {
        bondingCurve = _bondingCurve;
        unitToken = _unitToken;
    }

    function initialize() public override {
      super.initialize();
    }

    function sellUnit(uint256 unitAmount) external {
        // check beforeRR
        if (bondingCurve.getReserveRatio() > LOW_RR) {
          revert UnitAuctionTooHighRR();
        }
        if (block.timestamp - auctionStartTime > auctionMaxDuration) {
            revert UnitAuctionTerminated();
        }

        uint256 currentPrice = auctionStartTime * 99 ** ((block.timestamp - auctionStartTime) / 90 seconds) / 100;
        uint256 collateralAmount = unitAmount * currentPrice;
        
        unitToken.burnFrom(msg.sender, unitAmount);
        msg.sender.transferEth(collateralAmount); // TODO: change to collateral ERC20 token

        // check afterRR
        if (bondingCurve.getReserveRatio() > bondingCurve.HIGH_RR()) {
          revert UnitAuctionRRTooHigh();
        }
        // TODO: check if beforeRR < currentRR
    }

    function buyUnit(uint256 collateralAmount) external {
    }

    function _initializeAuction() internal {
        startPrice = bondingCurve.getMintPrice() * PRICE_BUFFER;
        auctionStartTime = block.timestamp;
    }
}