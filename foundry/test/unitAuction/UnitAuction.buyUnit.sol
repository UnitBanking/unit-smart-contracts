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
        uint256 currentPrice = 958482849005033943;
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
                1051049999999999999
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

    function test_buyUnit_SuccessfullyBuysUnitAfter33Minutes() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 userUnitBalanceBefore = unitToken.balanceOf(user);

        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(10 * 1e18); // increases RR

        unitAuctionProxy.refreshState();
        vm.warp(block.timestamp + 33 minutes);

        uint256 unitAmount = 99948227998754844;
        uint256 collateralAmount = 1e17;

        // Act & Assert
        vm.prank(user);
        unitAuctionProxy.buyUnit(collateralAmount);
        uint256 userUnitBalanceAfter = unitToken.balanceOf(user);
        assertEq(userUnitBalanceAfter - userUnitBalanceBefore, unitAmount);
    }

    function test_buyUnit_SuccessfullyBuysUnit() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(10 * 1e18); // increases RR

        uint256 userUnitBalanceBefore = unitToken.balanceOf(user);
        uint256 userCollateralBalanceBefore = collateralERC20Token.balanceOf(user);
        uint256 auctionCollateralBalanceBefore = collateralERC20Token.balanceOf(address(unitAuctionProxy));
        uint256 auctionUnitBalanceBefore = unitToken.balanceOf(address(unitAuctionProxy));
        uint256 bondingCurveCollateralBalanceBefore = collateralERC20Token.balanceOf(address(bondingCurveProxy));
        uint256 unitTotalSupplyBefore = unitToken.totalSupply();

        uint256 unitAmount = 99838290446758684;
        uint256 collateralAmount = 1e17;

        // Act
        vm.expectEmit();
        emit IUnitAuction.UnitBought(user, unitAmount, collateralAmount);
        vm.prank(user);
        unitAuctionProxy.buyUnit(collateralAmount);

        // Assert
        uint256 userUnitBalanceAfter = unitToken.balanceOf(user);
        uint256 userCollateralBalanceAfter = collateralERC20Token.balanceOf(user);
        uint256 auctionCollateralBalanceAfter = collateralERC20Token.balanceOf(address(unitAuctionProxy));
        uint256 auctionUnitBalanceAfter = unitToken.balanceOf(address(unitAuctionProxy));
        uint256 bondingCurveCollateralBalanceAfter = collateralERC20Token.balanceOf(address(bondingCurveProxy));
        uint256 unitTotalSupplyAfter = unitToken.totalSupply();
        assertEq(userUnitBalanceAfter - userUnitBalanceBefore, unitAmount);
        assertEq(userCollateralBalanceBefore - userCollateralBalanceAfter, collateralAmount);
        assertEq(auctionUnitBalanceAfter, auctionUnitBalanceBefore);
        assertEq(auctionCollateralBalanceAfter, auctionCollateralBalanceBefore);
        assertEq(unitTotalSupplyAfter - unitTotalSupplyBefore, unitAmount);
        assertEq(bondingCurveCollateralBalanceAfter - bondingCurveCollateralBalanceBefore, collateralAmount);
    }

    function test_buyUnit_SuccessfullyBuysUnit2Times() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(10 * 1e18); // increases RR

        uint256 userUnitBalanceBefore = unitToken.balanceOf(user);
        uint256 userCollateralBalanceBefore = collateralERC20Token.balanceOf(user);
        uint256 auctionCollateralBalanceBefore = collateralERC20Token.balanceOf(address(unitAuctionProxy));
        uint256 auctionUnitBalanceBefore = unitToken.balanceOf(address(unitAuctionProxy));
        uint256 bondingCurveCollateralBalanceBefore = collateralERC20Token.balanceOf(address(bondingCurveProxy));
        uint256 unitTotalSupplyBefore = unitToken.totalSupply();

        uint256 unitAmount = 99838290446758684;
        uint256 collateralAmount = 1e17;

        // Act
        vm.expectEmit();
        emit IUnitAuction.UnitBought(user, unitAmount, collateralAmount);
        vm.prank(user);
        unitAuctionProxy.buyUnit(collateralAmount);

        vm.expectEmit();
        emit IUnitAuction.UnitBought(user, unitAmount, collateralAmount);
        vm.prank(user);
        unitAuctionProxy.buyUnit(collateralAmount);

        // Assert
        uint256 userUnitBalanceAfter = unitToken.balanceOf(user);
        uint256 userCollateralBalanceAfter = collateralERC20Token.balanceOf(user);
        uint256 auctionCollateralBalanceAfter = collateralERC20Token.balanceOf(address(unitAuctionProxy));
        uint256 auctionUnitBalanceAfter = unitToken.balanceOf(address(unitAuctionProxy));
        uint256 bondingCurveCollateralBalanceAfter = collateralERC20Token.balanceOf(address(bondingCurveProxy));
        uint256 unitTotalSupplyAfter = unitToken.totalSupply();
        assertEq(userUnitBalanceAfter - userUnitBalanceBefore, unitAmount * 2);
        assertEq(userCollateralBalanceBefore - userCollateralBalanceAfter, collateralAmount * 2);
        assertEq(auctionUnitBalanceAfter, auctionUnitBalanceBefore);
        assertEq(auctionCollateralBalanceAfter, auctionCollateralBalanceBefore);
        assertEq(unitTotalSupplyAfter - unitTotalSupplyBefore, unitAmount * 2);
        assertEq(bondingCurveCollateralBalanceAfter - bondingCurveCollateralBalanceBefore, collateralAmount * 2);
    }

    function test_buyUnit_ChecksUnitPricingAtTheBeginningOfAuction() public {
        // Arrange
        address user = _setUpBondingCurveAndUnitAuction();
        uint256 userUnitBalanceBefore = unitToken.balanceOf(user);

        uint256 collateralAmount = 1e18;
        uint256 unitAmount = 3494340165636553958;

        // Act & Assert
        vm.expectEmit();
        emit IUnitAuction.UnitBought(user, unitAmount, collateralAmount);
        vm.prank(user);
        unitAuctionProxy.buyUnit(collateralAmount);

        uint256 userUnitBalanceAfter = unitToken.balanceOf(user);
        assertEq(userUnitBalanceAfter - userUnitBalanceBefore, unitAmount);
    }

    function test_buyUnit_ChecksUnitPricingInTheMiddleOfAuction() public {
        // Arrange
        address user = _setUpBondingCurveAndUnitAuction();
        uint256 userUnitBalanceBefore = unitToken.balanceOf(user);
        uint256 expansionAuctionMaxDuration = unitAuctionProxy.expansionAuctionMaxDuration();

        // set the middle of the expansion auction
        vm.warp(block.timestamp + (expansionAuctionMaxDuration / 2));

        uint256 collateralAmount = 1e18;
        uint256 unitAmount = 3575682516838096148;

        // decrease burn price
        collateralUsdOracle.setCollateralUsdPrice(40e17);

        // Act & Assert
        vm.expectEmit();
        emit IUnitAuction.UnitBought(user, unitAmount, collateralAmount);
        vm.prank(user);
        unitAuctionProxy.buyUnit(collateralAmount);

        uint256 userUnitBalanceAfter = unitToken.balanceOf(user);
        assertEq(userUnitBalanceAfter - userUnitBalanceBefore, unitAmount);
    }

    function test_buyUnit_ChecksUnitPricingAtTheEndOfAuction() public {
        // Arrange
        address user = _setUpBondingCurveAndUnitAuction();
        uint256 userUnitBalanceBefore = unitToken.balanceOf(user);
        uint256 expansionAuctionMaxDuration = unitAuctionProxy.expansionAuctionMaxDuration();

        // set the end of the expansion auction
        vm.warp(block.timestamp + expansionAuctionMaxDuration);

        uint256 collateralAmount = 1e18;
        uint256 unitAmount = 3658918380916278854;

        // decrease burn price
        collateralUsdOracle.setCollateralUsdPrice(40e17);

        // Act & Assert
        vm.expectEmit();
        emit IUnitAuction.UnitBought(user, unitAmount, collateralAmount);
        vm.prank(user);
        unitAuctionProxy.buyUnit(collateralAmount);

        uint256 userUnitBalanceAfter = unitToken.balanceOf(user);
        assertEq(userUnitBalanceAfter - userUnitBalanceBefore, unitAmount);
    }

    function _setUpBondingCurveAndUnitAuction() private returns (address) {
        // set collateral-usd price
        collateralUsdOracle.setCollateralUsdPrice(35e17);
        vm.warp(block.timestamp + 356 days);

        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(10000e18);

        // mint collateral and unit tokens
        address user = _createUserWithPrivateKeyAndMintUnitAndCollateralTokens(100, 1e18);
        _createUserWithPrivateKeyAndMintUnitAndCollateralTokens(200, 500 * 1e18);

        // start expansion auction
        unitAuctionProxy.refreshState();

        return user;
    }
}
