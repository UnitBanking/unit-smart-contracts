// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { UnitAuctionTestBase } from './UnitAuctionTestBase.t.sol';
import { IUnitAuction } from '../../../contracts/interfaces/IUnitAuction.sol';
import { TransferUtils } from '../../../contracts/libraries/TransferUtils.sol';

contract UnitAuctionBuyUnitTest is UnitAuctionTestBase {
    function test_buyUnit_RevertsWhenNoActiveExpansionAuction() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 collateralAmount = 1e18;

        // Act & Assert
        uint256 reserveRatio = 1001000000000000004;
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IUnitAuction.UnitAuctionInitialReserveRatioOutOfRange.selector, reserveRatio)
        );
        unitAuctionProxy.buyUnit(collateralAmount);
    }

    function test_buyUnit_RevertsWhenInsufficientUserCollateralBalance() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 collateralAmount = collateralERC20Token.balanceOf(user) + 1;

        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(5 * 1e18); // increases RR

        vm.prank(user);
        collateralERC20Token.approve(address(unitAuctionProxy), collateralAmount);

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                TransferUtils.TransferUtilsERC20TransferFromFailed.selector,
                address(collateralERC20Token),
                user,
                address(bondingCurveProxy),
                99000000000000000001
            )
        );
        unitAuctionProxy.buyUnit(collateralAmount);
    }

    function test_buyUnit_RevertsWhenCurrentPriceLowerThanBurnPrice() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 collateralAmount = collateralERC20Token.balanceOf(user);

        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(5 * 1e18); // increases RR

        unitAuctionProxy.refreshState();
        vm.warp(block.timestamp + 22 hours);

        // Act & Assert
        uint256 currentPrice = 957548447316224219;
        uint256 burnPrice = 999675189415101362;
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IUnitAuction.UnitAuctionPriceLowerThanBurnPrice.selector, currentPrice, burnPrice)
        );
        unitAuctionProxy.buyUnit(collateralAmount);
    }

    function test_buyUnit_RevertsWhenResultingReserveRatioOutOfRange() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 collateralAmount = collateralERC20Token.balanceOf(user);

        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(5 * 1e18); // increases RR

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IUnitAuction.UnitAuctionResultingReserveRatioOutOfRange.selector,
                1047687308787247517
            )
        );
        unitAuctionProxy.buyUnit(collateralAmount);
    }

    function test_buyUnit_RevertsWhenReserveRatioNotDecreased() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(10 * 1e18); // increases RR

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(IUnitAuction.UnitAuctionReserveRatioNotDecreased.selector);
        unitAuctionProxy.buyUnit(0);
    }

    function test_buyUnit_SuccessfullyBuysUnit() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(10 * 1e18); // increases RR

        uint256 unitBalanceBefore = unitToken.balanceOf(user);
        uint256 collateralBalanceBefore = collateralERC20Token.balanceOf(user);
        uint256 unitAmount = 100161971476592491;
        uint256 collateralAmount = 1e17;

        // Act
        vm.expectEmit();
        emit IUnitAuction.BuyUnit(user, unitAmount, collateralAmount);
        vm.prank(user);
        unitAuctionProxy.buyUnit(collateralAmount);

        // Assert
        uint256 unitBalanceAfter = unitToken.balanceOf(user);
        uint256 collateralBalanceAfter = collateralERC20Token.balanceOf(user);
        assertEq(unitBalanceAfter - unitBalanceBefore, unitAmount);
        assertEq(collateralBalanceBefore - collateralBalanceAfter, collateralAmount);
    }

    function test_buyUnit_SuccessfullyBuysUnit2Times() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(10 * 1e18); // increases RR

        uint256 unitBalanceBefore = unitToken.balanceOf(user);
        uint256 collateralBalanceBefore = collateralERC20Token.balanceOf(user);
        uint256 unitAmount = 100161971476592491;
        uint256 collateralAmount = 1e17;

        // Act
        vm.expectEmit();
        emit IUnitAuction.BuyUnit(user, unitAmount, collateralAmount);
        vm.prank(user);
        unitAuctionProxy.buyUnit(collateralAmount);

        vm.expectEmit();
        emit IUnitAuction.BuyUnit(user, unitAmount, collateralAmount);
        vm.prank(user);
        unitAuctionProxy.buyUnit(collateralAmount);

        // Assert
        uint256 unitBalanceAfter = unitToken.balanceOf(user);
        uint256 collateralBalanceAfter = collateralERC20Token.balanceOf(user);
        assertEq(unitBalanceAfter - unitBalanceBefore, unitAmount * 2);
        assertEq(collateralBalanceBefore - collateralBalanceAfter, collateralAmount * 2);
    }
}
