// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { BondingCurveTestBase } from './BondingCurveTestBase.t.sol';
import { IERC20 } from '../../../contracts/interfaces/IERC20.sol';

contract BondingCurveRedeemTest is BondingCurveTestBase {
    function test_redeem_SuccessfullyRedeemsCollateral() public {
        // Arrange
        uint256 mineTokenAmount = 1e18;
        address user = _createUserAndMintUnitAndMineTokens(1e18, mineTokenAmount);
        uint256 userCollateralBalanceBefore = collateralERC20TokenTest.balanceOf(user);
        uint256 bondingCurveCollateralBalanceBefore = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        uint256 mineTotalSupplyBefore = mineToken.totalSupply();
        vm.prank(user);
        mineToken.approve(address(bondingCurveProxy), mineTokenAmount);

        // Act
        vm.prank(user);
        bondingCurveProxy.redeem(mineTokenAmount);

        // Assert
        uint256 userCollateralBalanceAfter = collateralERC20TokenTest.balanceOf(user);
        uint256 bondingCurveCollateralBalanceAfter = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        uint256 mineTotalSupplyAfter = mineToken.totalSupply();
        assertEq(mineToken.balanceOf(user), 0);
        assertEq(userCollateralBalanceAfter, userCollateralBalanceBefore + 494505494505496);
        assertEq(bondingCurveCollateralBalanceBefore, bondingCurveCollateralBalanceAfter + 989010989010993);
        assertEq(mineTotalSupplyAfter, mineTotalSupplyBefore - mineTokenAmount);
    }

    function test_redeem_SuccessfullySkipsRedemptionDueToNoExcessCollateral() public {
        // Arrange
        uint256 mineTokenAmount = 1e8 * 1e18;
        address user = _createUserAndMintUnitAndMineTokens(1e18, mineTokenAmount);
        uint256 userCollateralBalanceBefore = collateralERC20TokenTest.balanceOf(user);
        uint256 bondingCurveCollateralBalanceBefore = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        uint256 mineTotalSupplyBefore = mineToken.totalSupply();
        vm.prank(user);
        mineToken.approve(address(bondingCurveProxy), mineTokenAmount);
        ethUsdOracle.setEthUsdPrice(1e16);

        // Act
        vm.prank(user);
        bondingCurveProxy.redeem(mineTokenAmount);

        // Assert
        uint256 userCollateralBalanceAfter = collateralERC20TokenTest.balanceOf(user);
        uint256 bondingCurveCollateralBalanceAfter = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        uint256 mineTotalSupplyAfter = mineToken.totalSupply();
        assertEq(mineToken.balanceOf(user), mineTokenAmount);
        assertEq(userCollateralBalanceAfter, userCollateralBalanceBefore);
        assertEq(bondingCurveCollateralBalanceAfter, bondingCurveCollateralBalanceBefore);
        assertEq(mineTotalSupplyAfter, mineTotalSupplyBefore);
    }

    function test_redeem_Redeems0MineTokens() public {
        // Arrange
        uint256 mineTokenAmount = 1e8 * 1e18;
        address user = _createUserAndMintUnitAndMineTokens(1e18, mineTokenAmount);
        uint256 mineTotalSupplyBefore = mineToken.totalSupply();
        uint256 bondingCurveCollateralBalanceBefore = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        uint256 userCollateralBalanceBefore = collateralERC20TokenTest.balanceOf(user);
        vm.prank(user);
        mineToken.approve(address(bondingCurveProxy), mineTokenAmount);

        // Act
        vm.prank(user);
        bondingCurveProxy.redeem(0);

        // Assert
        uint256 userMineBalanceAfter = mineToken.balanceOf(user);
        uint256 mineTotalSupplyAfter = mineToken.totalSupply();
        uint256 bondingCurveCollateralBalanceAfter = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        uint256 userCollateralBalanceAfter = collateralERC20TokenTest.balanceOf(user);
        assertEq(userMineBalanceAfter, mineTokenAmount);
        assertEq(mineTotalSupplyAfter, mineTotalSupplyBefore);
        assertEq(bondingCurveCollateralBalanceAfter, bondingCurveCollateralBalanceBefore);
        assertEq(userCollateralBalanceAfter, userCollateralBalanceBefore);
    }

    function test_redeem_RevertsIfUserTriesToRedeemMoreThanMineBalance() public {
        // Arrange
        uint256 mineTokenAmount = 1e8 * 1e18;
        address user = _createUserAndMintUnitAndMineTokens(1e18, mineTokenAmount);
        uint256 userMineBalance = mineToken.balanceOf(user);
        vm.prank(user);
        mineToken.approve(address(bondingCurveProxy), userMineBalance + 1);

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20.ERC20InsufficientBalance.selector, user, userMineBalance, userMineBalance + 1)
        );
        bondingCurveProxy.redeem(userMineBalance + 1);
    }
}
