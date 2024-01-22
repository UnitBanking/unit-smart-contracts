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
        uint256 reserveRatio = 1;
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

        vm.prank(address(bondingCurve));
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
                address(bondingCurve),
                99000000000000000001
            )
        );
        unitAuctionProxy.buyUnit(collateralAmount);
    }

    function test_buyUnit_RevertsWhenCurrentPriceLowerThanBurnPrice() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 collateralAmount = collateralERC20Token.balanceOf(user);

        vm.prank(address(bondingCurve));
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

        vm.prank(address(bondingCurve));
        collateralERC20Token.mint(5 * 1e18); // increases RR

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IUnitAuction.UnitAuctionResultingReserveRatioOutOfRange.selector, 1));
        unitAuctionProxy.buyUnit(collateralAmount);
    }

    function test_buyUnit_RevertsWhenReserveRatioNotDecreased() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        vm.prank(address(bondingCurve));
        collateralERC20Token.mint(10 * 1e18); // increases RR

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(IUnitAuction.UnitAuctionReserveRatioNotDecreased.selector);
        unitAuctionProxy.buyUnit(1);
    }

    function test_buyUnit_SuccessfullyBuysUnit() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        vm.prank(address(bondingCurve));
        collateralERC20Token.mint(10 * 1e18); // increases RR

        uint256 unitBalanceBefore = unitToken.balanceOf(user);

        // Act
        vm.prank(user);
        unitAuctionProxy.buyUnit(1e17);

        // Assert
        uint256 unitBalanceAfter = unitToken.balanceOf(user);
        assertEq(unitBalanceAfter - unitBalanceBefore, 100161971476592491);
    }

    function test_buyUnit_SuccessfullyBuysUnit2Times() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        vm.prank(address(bondingCurve));
        collateralERC20Token.mint(10 * 1e18); // increases RR

        uint256 unitBalanceBefore = unitToken.balanceOf(user);

        // Act
        vm.prank(user);
        unitAuctionProxy.buyUnit(1e17);
        vm.prank(user);
        unitAuctionProxy.buyUnit(1e17);

        // Assert
        uint256 unitBalanceAfter = unitToken.balanceOf(user);
        assertEq(unitBalanceAfter - unitBalanceBefore, 200323942953184982);
    }
}
