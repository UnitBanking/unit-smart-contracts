// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { Test, stdError } from 'forge-std/Test.sol';
import { BondingCurveHelper } from './BondingCurveHelper.t.sol';
import { BondingCurveHarness } from '../../../contracts/test/BondingCurveHarness.sol';
import { InflationOracleTest } from '../../../contracts/test/InflationOracleTest.sol';
import { EthUsdOracle } from '../../../contracts/EthUsdOracle.sol';
import { ERC20 } from '../../../contracts/ERC20.sol';
import { IBondingCurve } from '../../../contracts/interfaces/IBondingCurve.sol';

contract BondingCurveMintTest is BondingCurveHelper {
    function test_mint_SuccessfullyMintsUnitToken() public {
        // Arrange
        address user = vm.addr(2);
        uint256 etherValue = 1 ether;
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);
        uint256 bondingCurveBalanceBefore = address(bondingCurve).balance;

        // Act
        vm.prank(user);
        bondingCurve.mint{ value: etherValue }(user);

        // Assert
        uint256 bondingCurveBalanceAfter = address(bondingCurve).balance;
        assertEq(user.balance, userEthBalance - etherValue);
        assertEq(bondingCurveBalanceAfter - bondingCurveBalanceBefore, etherValue);
        assertEq(unitToken.balanceOf(user), 998382904467586844); //0.998382904467586844 UNIT
    }

    function test_mint_SuccessfullyMintsUnitTokenFor2Users() public {
        // Arrange
        address user1 = vm.addr(2);
        address user2 = vm.addr(3);
        uint256 user1EtherValue = 1 ether;
        uint256 user2EtherValue = 1 ether;
        uint256 userEthBalance = 100 ether;
        vm.deal(user1, userEthBalance);
        vm.deal(user2, userEthBalance);
        vm.prank(wallet);
        payable(address(bondingCurve)).transfer(5 ether); // increases RR
        vm.warp(START_TIMESTAMP + 10 days);
        uint256 bondingCurveBalanceBefore = address(bondingCurve).balance;

        // Act
        vm.prank(user1);
        bondingCurve.mint{ value: user1EtherValue }(user1);
        vm.prank(user2);
        bondingCurve.mint{ value: user2EtherValue }(user2);

        // Assert
        uint256 bondingCurveBalanceAfter = address(bondingCurve).balance;
        assertEq(user1.balance, userEthBalance - user1EtherValue);
        assertEq(user2.balance, userEthBalance - user2EtherValue);
        assertEq(bondingCurveBalanceAfter - bondingCurveBalanceBefore, user1EtherValue + user2EtherValue);
        assertEq(unitToken.balanceOf(user1), 998382904467586844); //0.998382904467586844 UNIT
        assertEq(unitToken.balanceOf(user2), 998382904467586844); //0.998382904467586844 UNIT
    }

    function test_mint_SendZeroEth() public {
        // Arrange
        address user = vm.addr(2);
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);
        uint256 bondingCurveBalanceBefore = address(bondingCurve).balance;

        // Act
        vm.prank(user);
        bondingCurve.mint{ value: 0 }(user);

        // Assert
        uint256 bondingCurveBalanceAfter = address(bondingCurve).balance;
        assertEq(user.balance, userEthBalance);
        assertEq(unitToken.balanceOf(user), 0);
        assertEq(bondingCurveBalanceBefore, bondingCurveBalanceAfter);
    }

    function test_mint_RevertIfReceiverIsAddressZero() public {
        // Arrange
        address user = vm.addr(2);
        uint256 etherValue = 1 ether;
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);

        // Act && Assert
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IBondingCurve.BondingCurveInvalidReceiver.selector, address(0)));
        bondingCurve.mint{ value: etherValue }(address(0));
    }

    function test_mint_RevertWhenReserveRatioBelowHighRR() public {
        // Arrange
        address user = vm.addr(2);
        uint256 etherValue = 1 ether;
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);
        vm.prank(address(bondingCurve));
        payable(address(0)).transfer(address(bondingCurve).balance); // remove ETH form BondingCurve to lower RR

        // Act && Assert
        vm.prank(user);
        vm.expectRevert(IBondingCurve.BondingCurveMintDisabledDueToTooLowRR.selector);
        bondingCurve.mint{ value: etherValue }(user);
    }

    function test_mint_SuccessfullyMintsWhenReserveRatioEqualsHighRR() public {
        // Arrange
        address user = vm.addr(2);
        uint256 etherValue = 1 ether;
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);
        uint256 bondingCurveBalanceBefore = address(bondingCurve).balance;
        assertEq(bondingCurve.getReserveRatio(), HIGH_RR);

        // Act
        vm.prank(user);
        bondingCurve.mint{ value: etherValue }(user);

        // Assert
        uint256 bondingCurveBalanceAfter = address(bondingCurve).balance;
        assertEq(user.balance, userEthBalance - etherValue);
        assertEq(bondingCurveBalanceAfter - bondingCurveBalanceBefore, etherValue);
        assertEq(unitToken.balanceOf(user), 998382904467586844); //0.998382904467586844 UNIT
    }

    function test_mint_SuccessfullyMintsWhenReserveRatioIsMuchHigherThanHighRR() public {
        // Arrange
        address user = vm.addr(2);
        uint256 etherValue = 1 ether;
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.deal(address(bondingCurve), type(uint256).max / ethUsdOracle.getEthUsdPrice());
        vm.warp(START_TIMESTAMP + 10 days);
        uint256 bondingCurveBalanceBefore = address(bondingCurve).balance;
        assertEq(bondingCurve.getReserveRatio(), 115720447209488867682148501081349782583534698222344066017616);

        // Act
        vm.prank(user);
        bondingCurve.mint{ value: etherValue }(user);

        // Assert
        uint256 bondingCurveBalanceAfter = address(bondingCurve).balance;
        assertEq(user.balance, userEthBalance - etherValue);
        assertEq(bondingCurveBalanceAfter - bondingCurveBalanceBefore, etherValue);
        assertEq(unitToken.balanceOf(user), 998382904467586844); //0.998382904467586844 UNIT
    }
}