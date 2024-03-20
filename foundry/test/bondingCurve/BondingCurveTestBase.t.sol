// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../TestBase.t.sol';

import { UnitAuctionHarness } from '../../../contracts/test/UnitAuctionHarness.sol';
import { BondingCurve } from '../../../contracts/BondingCurve.sol';

abstract contract BondingCurveTestBase is TestBase {
    BondingCurveHarness public bondingCurveImplementation;
    BondingCurveHarness public bondingCurveProxy;

    function setUp() public virtual {
        _setUp(18); // By default we set up an 18 decimal collateral token
    }

    function _setUp(uint8 collateralDecimals) internal {
        (address _bondingCurveImplementation, address _bondingCurveProxy) = _setUp(
            BondingCurveType.Test,
            collateralDecimals
        );
        bondingCurveImplementation = BondingCurveHarness(_bondingCurveImplementation);
        bondingCurveProxy = BondingCurveHarness(_bondingCurveProxy);
    }

    function _createUserAndMintUnit(uint256 collateralAmountIn) internal returns (address user) {
        // Arrange
        user = vm.addr(2);
        uint256 userCollateralBalance = 100 * 1e18;
        vm.startPrank(user);
        collateralToken.mint(userCollateralBalance);
        collateralToken.approve(address(bondingCurveProxy), userCollateralBalance);
        vm.stopPrank();

        vm.warp(TestUtils.START_TIMESTAMP + 10 days);

        // Act
        vm.prank(user);
        bondingCurveProxy.mint(user, collateralAmountIn);
    }

    function _mintMineToken(address receiver, uint256 value) internal {
        vm.prank(wallet);
        mineToken.mint(receiver, value);
    }

    function _createUserAndMintUnitAndMineTokens(
        uint256 collateralAmount,
        uint256 mineTokenAmount
    ) internal returns (address user) {
        user = _createUserAndMintUnit(collateralAmount);
        _mintMineToken(user, mineTokenAmount);
    }
}
