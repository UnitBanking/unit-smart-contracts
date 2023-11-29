// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { BondingCurveTestBase } from './BondingCurveHelper.t.sol';

contract BondingCurveRedeemTest is BondingCurveTestBase {
    function test_redeem_SuccessfullyRedeemsEth() public {
        // Arrange
        address user = _createUserAndMintUnit(1 ether);
        uint256 mineTokenAmount = 1e18;
        uint256 userEthBalanceBefore = user.balance;
        uint256 bondingCurveEthBalanceBefore = address(bondingCurve).balance;
        _mintMineToken(user, mineTokenAmount);
        vm.prank(user);
        mineToken.approve(address(bondingCurve), mineTokenAmount);

        // Act
        vm.prank(user);
        bondingCurve.redeem(mineTokenAmount);

        // Assert
        uint256 userEthBalanceAfter = user.balance;
        uint256 bondingCurveEthBalanceAfter = address(bondingCurve).balance;
        assertEq(mineToken.balanceOf(user), 0);
        assertEq(userEthBalanceAfter, userEthBalanceBefore + 494505494505496);
        assertEq(bondingCurveEthBalanceBefore, bondingCurveEthBalanceAfter + 989010989010993);
    }

    function test_redeem_FailedRedemptionDueToNoExcessEth() public {
        // Arrange
        address user = _createUserAndMintUnit(1 ether);
        uint256 mineTokenAmount = 1e10 * 1e18;
        uint256 userEthBalanceBefore = user.balance;
        uint256 bondingCurveEthBalanceBefore = address(bondingCurve).balance;
        _mintMineToken(user, mineTokenAmount);
        vm.prank(user);
        mineToken.approve(address(bondingCurve), mineTokenAmount);
        ethUsdOracle.setEthUsdPrice(1e16);

        // Act
        vm.prank(user);
        bondingCurve.redeem(mineTokenAmount);

        // Assert
        uint256 userEthBalanceAfter = user.balance;
        uint256 bondingCurveEthBalanceAfter = address(bondingCurve).balance;
        assertEq(mineToken.balanceOf(user), mineTokenAmount);
        assertEq(userEthBalanceAfter, userEthBalanceBefore);
        assertEq(bondingCurveEthBalanceAfter, bondingCurveEthBalanceBefore);
    }
}
