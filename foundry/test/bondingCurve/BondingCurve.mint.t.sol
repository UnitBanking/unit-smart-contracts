// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { BondingCurveTestBase } from './BondingCurveTestBase.t.sol';
import { IBondingCurve } from '../../../contracts/interfaces/IBondingCurve.sol';
import { Mintable } from '../../../contracts/abstracts/Mintable.sol';
import { TestUtils } from '../utils/TestUtils.t.sol';

contract BondingCurveMintTest is BondingCurveTestBase {
    function test_mint_SuccessfullyMintsUnitToken() public {
        // Arrange
        address user = vm.addr(2);
        uint256 collateralAmountIn = 1e18;
        uint256 userCollateralBalance = 100 * 1e18;
        vm.startPrank(user);
        collateralERC20TokenTest.mint(userCollateralBalance);
        collateralERC20TokenTest.approve(address(bondingCurveProxy), userCollateralBalance);
        vm.stopPrank();

        vm.warp(TestUtils.START_TIMESTAMP + 10 days);
        uint256 bondingCurveBalanceBefore = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));

        // Act
        vm.prank(user);
        bondingCurveProxy.mint(user, collateralAmountIn);

        // Assert
        uint256 bondingCurveBalanceAfter = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        uint256 userBalanceAfter = collateralERC20TokenTest.balanceOf(user);
        assertEq(userBalanceAfter, userCollateralBalance - collateralAmountIn);
        assertEq(bondingCurveBalanceAfter - bondingCurveBalanceBefore, collateralAmountIn);
        assertEq(unitToken.balanceOf(user), 998382904467586844); //0.998382904467586844 UNIT
    }

    function test_mint_SuccessfullyMintsUnitTokenFor2Users() public {
        // Arrange
        address user1 = vm.addr(2);
        address user2 = vm.addr(3);
        uint256 user1CollateralAmountIn = 1e18;
        uint256 user2CollateralAmountIn = 1e18;
        uint256 userCollateralBalance = 100 * 1e18;
        vm.startPrank(user1);
        collateralERC20TokenTest.mint(userCollateralBalance);
        collateralERC20TokenTest.approve(address(bondingCurveProxy), userCollateralBalance);
        vm.stopPrank();
        vm.startPrank(user2);
        collateralERC20TokenTest.mint(userCollateralBalance);
        collateralERC20TokenTest.approve(address(bondingCurveProxy), userCollateralBalance);
        vm.stopPrank();

        vm.prank(address(bondingCurveProxy));
        collateralERC20TokenTest.mint(5 * 1e18); // increases RR
        uint256 bondingCurveBalanceBefore = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));

        vm.warp(TestUtils.START_TIMESTAMP + 10 days);

        // Act
        vm.prank(user1);
        bondingCurveProxy.mint(user1, user1CollateralAmountIn);
        vm.prank(user2);
        bondingCurveProxy.mint(user2, user2CollateralAmountIn);

        // Assert
        uint256 bondingCurveBalanceAfter = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        uint256 user1BalanceAfter = collateralERC20TokenTest.balanceOf(user1);
        uint256 user2BalanceAfter = collateralERC20TokenTest.balanceOf(user2);
        assertEq(user1BalanceAfter, userCollateralBalance - user1CollateralAmountIn);
        assertEq(user2BalanceAfter, userCollateralBalance - user2CollateralAmountIn);
        assertEq(
            bondingCurveBalanceAfter - bondingCurveBalanceBefore,
            user1CollateralAmountIn + user2CollateralAmountIn
        );
        assertEq(unitToken.balanceOf(user1), 998382904467586844); //0.998382904467586844 UNIT
        assertEq(unitToken.balanceOf(user2), 998382904467586844); //0.998382904467586844 UNIT
    }

    function test_mint_SendZeroCollateralToken() public {
        // Arrange
        address user = vm.addr(2);
        uint256 userCollateralBalance = 100 * 1e18;
        vm.startPrank(user);
        collateralERC20TokenTest.mint(userCollateralBalance);
        collateralERC20TokenTest.approve(address(bondingCurveProxy), userCollateralBalance);
        vm.stopPrank();
        vm.warp(TestUtils.START_TIMESTAMP + 10 days);
        uint256 bondingCurveBalanceBefore = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));

        // Act
        vm.prank(user);
        bondingCurveProxy.mint(user, 0);

        // Assert
        uint256 bondingCurveBalanceAfter = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        uint256 userBalanceAfter = collateralERC20TokenTest.balanceOf(user);
        assertEq(userBalanceAfter, userCollateralBalance);
        assertEq(unitToken.balanceOf(user), 0);
        assertEq(bondingCurveBalanceBefore, bondingCurveBalanceAfter);
    }

    function test_mint_RevertIfReceiverIsAddressZero() public {
        // Arrange
        address user = vm.addr(2);
        uint256 collateralAmountIn = 1e18;
        uint256 userCollateralBalance = 100 * 1e18;
        vm.startPrank(user);
        collateralERC20TokenTest.mint(userCollateralBalance);
        collateralERC20TokenTest.approve(address(bondingCurveProxy), userCollateralBalance);
        vm.stopPrank();
        vm.warp(TestUtils.START_TIMESTAMP + 10 days);

        // Act && Assert
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Mintable.MintableInvalidReceiver.selector, address(0)));
        bondingCurveProxy.mint(address(0), collateralAmountIn);
    }

    function test_mint_RevertWhenReserveRatioBelowHighRR() public {
        // Arrange
        address user = vm.addr(2);
        uint256 collateralAmountIn = 1e18;
        uint256 userCollateralBalance = 100 * 1e18;
        vm.startPrank(user);
        collateralERC20TokenTest.mint(userCollateralBalance);
        collateralERC20TokenTest.approve(address(bondingCurveProxy), userCollateralBalance);
        vm.stopPrank();
        vm.warp(TestUtils.START_TIMESTAMP + 10 days);

        uint256 bondingCurveCollateralBalance = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        vm.prank(address(bondingCurveProxy));
        collateralERC20TokenTest.burn(bondingCurveCollateralBalance); // remove collateral token form BondingCurve to lower RR

        // Act && Assert
        vm.prank(user);
        vm.expectRevert(IBondingCurve.BondingCurveReserveRatioTooLow.selector);
        bondingCurveProxy.mint(user, collateralAmountIn);
    }

    function test_mint_SuccessfullyMintsWhenReserveRatioEqualsHighRR() public {
        // Arrange
        address user = vm.addr(2);
        uint256 collateralAmountIn = 1e18;
        uint256 userCollateralBalance = 100 * 1e18;
        vm.startPrank(user);
        collateralERC20TokenTest.mint(userCollateralBalance);
        collateralERC20TokenTest.approve(address(bondingCurveProxy), userCollateralBalance);
        vm.stopPrank();
        vm.warp(TestUtils.START_TIMESTAMP + 10 days);
        uint256 bondingCurveBalanceBefore = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        assertEq(
            bondingCurveProxy.getReserveRatio() / TestUtils.RR_PRECISION,
            TestUtils.HIGH_RR / TestUtils.RR_PRECISION
        );

        // Act
        vm.prank(user);
        bondingCurveProxy.mint(user, collateralAmountIn);

        // Assert
        uint256 bondingCurveBalanceAfter = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        uint256 userBalanceAfter = collateralERC20TokenTest.balanceOf(user);
        assertEq(userBalanceAfter, userCollateralBalance - collateralAmountIn);
        assertEq(bondingCurveBalanceAfter - bondingCurveBalanceBefore, collateralAmountIn);
        assertEq(unitToken.balanceOf(user), 998382904467586844); //0.998382904467586844 UNIT
    }

    function test_mint_SuccessfullyMintsWhenReserveRatioIsMuchHigherThanHighRR() public {
        // Arrange
        address user = vm.addr(2);
        uint256 collateralAmountIn = 1e18;
        uint256 userCollateralBalance = 100 * 1e18;
        vm.startPrank(user);
        collateralERC20TokenTest.mint(userCollateralBalance);
        collateralERC20TokenTest.approve(address(bondingCurveProxy), userCollateralBalance);
        vm.stopPrank();

        vm.startPrank(address(bondingCurveProxy));
        collateralERC20TokenTest.mint(userCollateralBalance * 10);
        vm.stopPrank();

        vm.warp(TestUtils.START_TIMESTAMP + 10 days);
        uint256 bondingCurveBalanceBefore = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        assertEq(bondingCurveProxy.getReserveRatio(), 999381287372054430990364809209393220250);

        // Act
        vm.prank(user);
        bondingCurveProxy.mint(user, collateralAmountIn);

        // Assert
        uint256 bondingCurveBalanceAfter = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        uint256 userBalanceAfter = collateralERC20TokenTest.balanceOf(user);
        assertEq(userBalanceAfter, userCollateralBalance - collateralAmountIn);
        assertEq(bondingCurveBalanceAfter - bondingCurveBalanceBefore, collateralAmountIn);
        assertEq(unitToken.balanceOf(user), 998382904467586844); //0.998382904467586844 UNIT
    }
}
