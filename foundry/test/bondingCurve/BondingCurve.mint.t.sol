// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { BondingCurveTestBase } from './BondingCurveTestBase.t.sol';
import { IBondingCurve } from '../../../contracts/interfaces/IBondingCurve.sol';
import { Mintable } from '../../../contracts/abstracts/Mintable.sol';
import { TestUtils } from './TestUtils.sol';

contract BondingCurveMintTest is BondingCurveTestBase {
    function test_mint_SuccessfullyMintsUnitToken() public {
        // Arrange
        address user = vm.addr(2);
        uint256 collateralAmountIn = 1 ether;
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);
        uint256 bondingCurveBalanceBefore = address(bondingCurveProxy).balance;

        // Act
        vm.prank(user);
        bondingCurveProxy.mint(user, collateralAmountIn);

        // Assert
        uint256 bondingCurveBalanceAfter = address(bondingCurveProxy).balance;
        assertEq(user.balance, userEthBalance - collateralAmountIn);
        assertEq(bondingCurveBalanceAfter - bondingCurveBalanceBefore, collateralAmountIn);
        assertEq(unitToken.balanceOf(user), 998382904467586844); //0.998382904467586844 UNIT
    }

    function test_mint_SuccessfullyMintsUnitTokenFor2Users() public {
        // Arrange
        address user1 = vm.addr(2);
        address user2 = vm.addr(3);
        uint256 user1collateralAmountIn = 1 ether;
        uint256 user2collateralAmountIn = 1 ether;
        uint256 userEthBalance = 100 ether;
        vm.deal(user1, userEthBalance);
        vm.deal(user2, userEthBalance);
        vm.prank(wallet);
        TestUtils.transferEth(address(bondingCurveProxy), 5 ether); // increases RR
        vm.warp(START_TIMESTAMP + 10 days);
        uint256 bondingCurveBalanceBefore = address(bondingCurveProxy).balance;

        // Act
        vm.prank(user1);
        bondingCurveProxy.mint(user1, user1collateralAmountIn);
        vm.prank(user2);
        bondingCurveProxy.mint(user2, user2collateralAmountIn);

        // Assert
        uint256 bondingCurveBalanceAfter = address(bondingCurveProxy).balance;
        assertEq(user1.balance, userEthBalance - user1collateralAmountIn);
        assertEq(user2.balance, userEthBalance - user2collateralAmountIn);
        assertEq(
            bondingCurveBalanceAfter - bondingCurveBalanceBefore,
            user1collateralAmountIn + user2collateralAmountIn
        );
        assertEq(unitToken.balanceOf(user1), 998382904467586844); //0.998382904467586844 UNIT
        assertEq(unitToken.balanceOf(user2), 998382904467586844); //0.998382904467586844 UNIT
    }

    function test_mint_SendZeroEth() public {
        // Arrange
        address user = vm.addr(2);
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);
        uint256 bondingCurveBalanceBefore = address(bondingCurveProxy).balance;

        // Act
        vm.prank(user);
        bondingCurveProxy.mint(user, 0);

        // Assert
        uint256 bondingCurveBalanceAfter = address(bondingCurveProxy).balance;
        assertEq(user.balance, userEthBalance);
        assertEq(unitToken.balanceOf(user), 0);
        assertEq(bondingCurveBalanceBefore, bondingCurveBalanceAfter);
    }

    function test_mint_RevertIfReceiverIsAddressZero() public {
        // Arrange
        address user = vm.addr(2);
        uint256 collateralAmountIn = 1 ether;
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);

        // Act && Assert
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Mintable.MintableInvalidReceiver.selector, address(0)));
        bondingCurveProxy.mint(address(0), collateralAmountIn);
    }

    function test_mint_RevertWhenReserveRatioBelowHighRR() public {
        // Arrange
        address user = vm.addr(2);
        uint256 collateralAmountIn = 1 ether;
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);
        vm.prank(address(bondingCurveProxy));
        payable(address(0)).transfer(address(bondingCurveProxy).balance); // remove ETH form BondingCurve to lower RR

        // Act && Assert
        vm.prank(user);
        vm.expectRevert(IBondingCurve.BondingCurveReserveRatioTooLow.selector);
        bondingCurveProxy.mint(user, collateralAmountIn);
    }

    function test_mint_SuccessfullyMintsWhenReserveRatioEqualsHighRR() public {
        // Arrange
        address user = vm.addr(2);
        uint256 collateralAmountIn = 1 ether;
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);
        uint256 bondingCurveBalanceBefore = address(bondingCurveProxy).balance;
        assertEq(bondingCurveProxy.getReserveRatio(), HIGH_RR);

        // Act
        vm.prank(user);
        bondingCurveProxy.mint(user, collateralAmountIn);

        // Assert
        uint256 bondingCurveBalanceAfter = address(bondingCurveProxy).balance;
        assertEq(user.balance, userEthBalance - collateralAmountIn);
        assertEq(bondingCurveBalanceAfter - bondingCurveBalanceBefore, collateralAmountIn);
        assertEq(unitToken.balanceOf(user), 998382904467586844); //0.998382904467586844 UNIT
    }

    function test_mint_SuccessfullyMintsWhenReserveRatioIsMuchHigherThanHighRR() public {
        // Arrange
        address user = vm.addr(2);
        uint256 collateralAmountIn = 1 ether;
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.deal(address(bondingCurveProxy), type(uint256).max / ethUsdOracle.getEthUsdPrice());
        vm.warp(START_TIMESTAMP + 10 days);
        uint256 bondingCurveBalanceBefore = address(bondingCurveProxy).balance;
        assertEq(bondingCurveProxy.getReserveRatio(), 115720447209488867682148501081349782583534698222344066017616);

        // Act
        vm.prank(user);
        bondingCurveProxy.mint(user, collateralAmountIn);

        // Assert
        uint256 bondingCurveBalanceAfter = address(bondingCurveProxy).balance;
        assertEq(user.balance, userEthBalance - collateralAmountIn);
        assertEq(bondingCurveBalanceAfter - bondingCurveBalanceBefore, collateralAmountIn);
        assertEq(unitToken.balanceOf(user), 998382904467586844); //0.998382904467586844 UNIT
    }
}
