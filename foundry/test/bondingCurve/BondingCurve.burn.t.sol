// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { BondingCurveTestBase } from './BondingCurveTestBase.t.sol';
import { IERC20 } from '../../../contracts/interfaces/IERC20.sol';

contract BondingCurveBurnTest is BondingCurveTestBase {
    function test_burn_SuccessfullyBurnsUnitToken() public {
        // Arrange
        uint256 etherValue = 1 ether;
        address user = _createUserAndMintUnit(etherValue);
        uint256 unitTokenBalanceBefore = unitToken.balanceOf(user);
        uint256 userEthBalanceBefore = user.balance;
        uint256 bondingCurveEthBalanceBefore = address(bondingCurve).balance;
        uint256 burnAmount = 499191452233793422; // 998382904467586844/2
        uint256 ethWithdrawnAmount = 499000999000999000;
        vm.prank(user);
        unitToken.approve(address(bondingCurve), 998382904467586844);

        // Act
        vm.prank(user);
        bondingCurve.burn(burnAmount);

        // Assert
        uint256 unitTokenBalanceAfter = unitToken.balanceOf(user);
        uint256 userEthBalanceAfter = user.balance;
        uint256 bondingCurveEthBalanceAfter = address(bondingCurve).balance;
        assertEq(unitTokenBalanceAfter, unitTokenBalanceBefore - burnAmount);
        assertEq(userEthBalanceAfter - userEthBalanceBefore, ethWithdrawnAmount);
        assertEq(bondingCurveEthBalanceBefore - bondingCurveEthBalanceAfter, ethWithdrawnAmount);
    }

    function test_burn_Burns0UnitToken() public {
        // Arrange
        uint256 etherValue = 1 ether;
        address user = _createUserAndMintUnit(etherValue);
        uint256 unitTokenBalanceBefore = unitToken.balanceOf(user);
        uint256 userEthBalanceBefore = user.balance;
        uint256 bondingCurveEthBalanceBefore = address(bondingCurve).balance;

        // Act
        vm.prank(user);
        bondingCurve.burn(0);

        // Assert
        uint256 unitTokenBalanceAfter = unitToken.balanceOf(user);
        uint256 userEthBalanceAfter = user.balance;
        uint256 bondingCurveEthBalanceAfter = address(bondingCurve).balance;
        assertEq(unitTokenBalanceAfter, unitTokenBalanceBefore);
        assertEq(userEthBalanceBefore, userEthBalanceAfter);
        assertEq(bondingCurveEthBalanceBefore, bondingCurveEthBalanceAfter);
    }

    function test_burn_RevertsIfUserTriesToBurnMoreThanUnitBalance() public {
        // Arrange
        uint256 etherValue = 1 ether;
        address user = _createUserAndMintUnit(etherValue);
        uint256 userUnitBalance = unitToken.balanceOf(user);
        uint256 additionalUnitAmount = 1;
        uint256 burnAmount = userUnitBalance + additionalUnitAmount;
        vm.prank(user);
        unitToken.approve(address(bondingCurve), burnAmount);
        vm.prank(address(bondingCurve));
        unitToken.mint(wallet, additionalUnitAmount);

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IERC20.ERC20InsufficientBalance.selector, user, userUnitBalance, burnAmount));
        bondingCurve.burn(burnAmount);
    }

    function test_burn_RevertsIfUserTriesToBurnMoreThanUnitTotalSupply() public {
        // Arrange
        uint256 etherValue = 1 ether;
        address user = _createUserAndMintUnit(etherValue);
        uint256 userUnitBalance = unitToken.balanceOf(user);
        uint256 burnAmount = unitToken.totalSupply() + 1;
        vm.prank(user);
        unitToken.approve(address(bondingCurve), burnAmount);

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IERC20.ERC20InsufficientBalance.selector, user, userUnitBalance, burnAmount));
        bondingCurve.burn(burnAmount);
    }

    function test_burn_RevertsIfUserTriesToBurnMoreThanUnitAllowance() public {
        // Arrange
        uint256 etherValue = 1 ether;
        address user = _createUserAndMintUnit(etherValue);
        uint256 userUnitBalance = unitToken.balanceOf(user);
        uint256 allowedAmount = userUnitBalance - 1;
        uint256 burnAmount = allowedAmount + 1;
        vm.prank(user);
        unitToken.approve(address(bondingCurve), allowedAmount);
        vm.prank(address(bondingCurve));
        unitToken.mint(wallet, 1);

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IERC20.ERC20InsufficientAllowance.selector, address(bondingCurve), allowedAmount, burnAmount));
        bondingCurve.burn(burnAmount);
    }
}
