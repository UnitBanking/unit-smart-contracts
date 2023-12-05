// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { BondingCurveTestBase } from './BondingCurveTestBase.t.sol';
import { IERC20 } from '../../../contracts/interfaces/IERC20.sol';

contract BondingCurveRedeemTest is BondingCurveTestBase {
    function test_redeem_SuccessfullyRedeemsEth() public {
        // Arrange
        uint256 mineTokenAmount = 1e18;
        address user = _createUserAndMintUnitAndMineTokens(1 ether, mineTokenAmount);
        uint256 userEthBalanceBefore = user.balance;
        uint256 bondingCurveEthBalanceBefore = address(bondingCurve).balance;
        uint256 mineTotalSupplyBefore = mineToken.totalSupply();
        vm.prank(user);
        mineToken.approve(address(bondingCurve), mineTokenAmount);

        // Act
        vm.prank(user);
        bondingCurve.redeem(mineTokenAmount);

        // Assert
        uint256 userEthBalanceAfter = user.balance;
        uint256 bondingCurveEthBalanceAfter = address(bondingCurve).balance;
        uint256 mineTotalSupplyAfter = mineToken.totalSupply();
        assertEq(mineToken.balanceOf(user), 0);
        assertEq(userEthBalanceAfter, userEthBalanceBefore + 494505494505496);
        assertEq(bondingCurveEthBalanceBefore, bondingCurveEthBalanceAfter + 989010989010993);
        assertEq(mineTotalSupplyAfter, mineTotalSupplyBefore - mineTokenAmount);
    }

    function test_redeem_SuccessfullySkipsRedemptionDueToNoExcessEth() public {
        // Arrange
        uint256 mineTokenAmount = 1e8 * 1e18;
        address user = _createUserAndMintUnitAndMineTokens(1 ether, mineTokenAmount);
        uint256 userEthBalanceBefore = user.balance;
        uint256 bondingCurveEthBalanceBefore = address(bondingCurve).balance;
        uint256 mineTotalSupplyBefore = mineToken.totalSupply();
        vm.prank(user);
        mineToken.approve(address(bondingCurve), mineTokenAmount);
        ethUsdOracle.setEthUsdPrice(1e16);

        // Act
        vm.prank(user);
        bondingCurve.redeem(mineTokenAmount);

        // Assert
        uint256 userEthBalanceAfter = user.balance;
        uint256 bondingCurveEthBalanceAfter = address(bondingCurve).balance;
        uint256 mineTotalSupplyAfter = mineToken.totalSupply();
        assertEq(mineToken.balanceOf(user), mineTokenAmount);
        assertEq(userEthBalanceAfter, userEthBalanceBefore);
        assertEq(bondingCurveEthBalanceAfter, bondingCurveEthBalanceBefore);
        assertEq(mineTotalSupplyAfter, mineTotalSupplyBefore);
    }

    function test_redeem_Redeems0MineTokens() public {
        // Arrange
        uint256 mineTokenAmount = 1e8 * 1e18;
        address user = _createUserAndMintUnitAndMineTokens(1 ether, mineTokenAmount);
        uint256 mineTotalSupplyBefore = mineToken.totalSupply();
        uint256 bondingCurveEthBalanceBefore = address(bondingCurve).balance;
        uint256 userEthBalanceBefore = user.balance;
        vm.prank(user);
        mineToken.approve(address(bondingCurve), mineTokenAmount);

        // Act
        vm.prank(user);
        bondingCurve.redeem(0);

        // Assert
        uint256 userMineBalanceAfter = mineToken.balanceOf(user);
        uint256 mineTotalSupplyAfter = mineToken.totalSupply();
        uint256 bondingCurveEthBalanceAfter = address(bondingCurve).balance;
        uint256 userEthBalanceAfter = user.balance;
        assertEq(userMineBalanceAfter, mineTokenAmount);
        assertEq(mineTotalSupplyAfter, mineTotalSupplyBefore);
        assertEq(bondingCurveEthBalanceAfter, bondingCurveEthBalanceBefore);
        assertEq(userEthBalanceAfter, userEthBalanceBefore);
    }

    function test_redeem_RevertsIfUserTriesToRedeemMoreThanMineBalance() public {
        // Arrange
        uint256 mineTokenAmount = 1e8 * 1e18;
        address user = _createUserAndMintUnitAndMineTokens(1 ether, mineTokenAmount);
        uint256 userMineBalance = mineToken.balanceOf(user);
        vm.prank(user);
        mineToken.approve(address(bondingCurve), userMineBalance + 1);

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IERC20.ERC20InsufficientBalance.selector, user, userMineBalance, userMineBalance + 1));
        bondingCurve.redeem(userMineBalance + 1);
    }
}
