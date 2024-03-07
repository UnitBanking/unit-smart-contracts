// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { UnitAuction } from '../auctions/UnitAuction.sol';
import '../BondingCurve.sol';
import '../UnitToken.sol';

contract UnitAuctionHarness is UnitAuction {
    constructor(BondingCurve _bondingCurve, UnitToken _unitToken) UnitAuction(_bondingCurve, _unitToken) {}

    function exposed_startContractionAuction() external returns (AuctionState memory _auctionState) {
        return _startContractionAuction();
    }

    function exposed_startExpansionAuction() external returns (AuctionState memory _auctionState) {
        return _startExpansionAuction();
    }

    function exposed_terminateAuction() external returns (AuctionState memory _auctionState) {
        return _terminateAuction();
    }

    function exposed_inContractionRange(uint256 reserveRatio) external pure returns (bool) {
        return inContractionRange(reserveRatio);
    }

    function exposed_inExpansionRange(uint256 reserveRatio) external pure returns (bool) {
        return inExpansionRange(reserveRatio);
    }

    function exposed_collateralTokenDecimals() external view returns (uint256) {
        return collateralTokenDecimals;
    }
}
