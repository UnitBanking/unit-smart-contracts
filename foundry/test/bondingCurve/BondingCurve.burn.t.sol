// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { BondingCurveTestBase } from './BondingCurveTestBase.t.sol';
import { IERC20 } from '../../../contracts/interfaces/IERC20.sol';

contract BondingCurveBurnTest is BondingCurveTestBase {
    function test_burn_SuccessfullyBurnsUnitToken() public {
        // Arrange
        uint256 collateralAmount = 1e18;
        address user = _createUserAndMintUnit(collateralAmount);
        uint256 unitTokenBalanceBefore = unitToken.balanceOf(user);
        uint256 userCollateralBalanceBefore = collateralERC20TokenTest.balanceOf(user);
        uint256 bondingCurveCollateralBalanceBefore = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        uint256 burnAmount = 499191452233793422; // 998382904467586844/2
        uint256 collateralWithdrawnAmount = 499000999000999000;
        vm.prank(user);
        unitToken.approve(address(bondingCurveProxy), 998382904467586844);

        // Act
        vm.prank(user);
        bondingCurveProxy.burn(burnAmount);

        // Assert
        uint256 unitTokenBalanceAfter = unitToken.balanceOf(user);
        uint256 userCollateralBalanceAfter = collateralERC20TokenTest.balanceOf(user);
        uint256 bondingCurveCollateralBalanceAfter = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        assertEq(unitTokenBalanceAfter, unitTokenBalanceBefore - burnAmount);
        assertEq(userCollateralBalanceAfter - userCollateralBalanceBefore, collateralWithdrawnAmount);
        assertEq(bondingCurveCollateralBalanceBefore - bondingCurveCollateralBalanceAfter, collateralWithdrawnAmount);
    }

    function test_burn_Burns0UnitToken() public {
        // Arrange
        uint256 collateralAmount = 1e18;
        address user = _createUserAndMintUnit(collateralAmount);
        uint256 unitTokenBalanceBefore = unitToken.balanceOf(user);
        uint256 userCollateralBalanceBefore = collateralERC20TokenTest.balanceOf(user);
        uint256 bondingCurveCollateralBalanceBefore = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));

        // Act
        vm.prank(user);
        bondingCurveProxy.burn(0);

        // Assert
        uint256 unitTokenBalanceAfter = unitToken.balanceOf(user);
        uint256 userCollateralBalanceAfter = collateralERC20TokenTest.balanceOf(user);
        uint256 bondingCurveCollateralBalanceAfter = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        assertEq(unitTokenBalanceAfter, unitTokenBalanceBefore);
        assertEq(userCollateralBalanceBefore, userCollateralBalanceAfter);
        assertEq(bondingCurveCollateralBalanceBefore, bondingCurveCollateralBalanceAfter);
    }

    function test_burn_RevertsIfUserTriesToBurnMoreThanUnitBalance() public {
        // Arrange
        uint256 collateralAmount = 1e18;
        address user = _createUserAndMintUnit(collateralAmount);
        uint256 userUnitBalance = unitToken.balanceOf(user);
        uint256 additionalUnitAmount = 1;
        uint256 burnAmount = userUnitBalance + additionalUnitAmount;
        vm.prank(user);
        unitToken.approve(address(bondingCurveProxy), burnAmount);
        vm.prank(address(bondingCurveProxy));
        unitToken.mint(wallet, additionalUnitAmount);

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20.ERC20InsufficientBalance.selector, user, userUnitBalance, burnAmount)
        );
        bondingCurveProxy.burn(burnAmount);
    }

    function test_burn_RevertsIfUserTriesToBurnMoreThanUnitTotalSupply() public {
        // Arrange
        uint256 collateralAmount = 1e18;
        address user = _createUserAndMintUnit(collateralAmount);
        uint256 userUnitBalance = unitToken.balanceOf(user);
        uint256 burnAmount = unitToken.totalSupply() + 1;
        vm.prank(user);
        unitToken.approve(address(bondingCurveProxy), burnAmount);

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20.ERC20InsufficientBalance.selector, user, userUnitBalance, burnAmount)
        );
        bondingCurveProxy.burn(burnAmount);
    }

    function test_burn_RevertsIfUserTriesToBurnMoreThanUnitAllowance() public {
        // Arrange
        uint256 collateralAmount = 1e18;
        address user = _createUserAndMintUnit(collateralAmount);
        uint256 userUnitBalance = unitToken.balanceOf(user);
        uint256 allowedAmount = userUnitBalance - 1;
        uint256 burnAmount = allowedAmount + 1;
        vm.prank(user);
        unitToken.approve(address(bondingCurveProxy), allowedAmount);
        vm.prank(address(bondingCurveProxy));
        unitToken.mint(wallet, 1);

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20.ERC20InsufficientAllowance.selector,
                address(bondingCurveProxy),
                allowedAmount,
                burnAmount
            )
        );
        bondingCurveProxy.burn(burnAmount);
    }
}
