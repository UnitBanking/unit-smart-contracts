// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { Test, stdError } from 'forge-std/Test.sol';
import { BondingCurveHelper } from './BondingCurveHelper.t.sol';
import { BondingCurveHarness } from '../../../contracts/test/BondingCurveHarness.sol';
import { InflationOracleTest } from '../../../contracts/test/InflationOracleTest.sol';
import { EthUsdOracle } from '../../../contracts/EthUsdOracle.sol';
import { ERC20 } from '../../../contracts/ERC20.sol';
import { IBondingCurve } from '../../../contracts/interfaces/IBondingCurve.sol';

contract BondingCurveRedeemTest is BondingCurveHelper {
    function test_redeem_SuccessfullyRedeemsEth() public {
        // Arrange
        address user = _createUserAndMintUnit(1 ether);
        uint256 mineTokenAmount = 1e18;
        uint256 userEthBalanceBefore = user.balance;
        uint256 bondingCurveEthBalanceBefore = address(bondingCurve).balance;
        _mintMineToken(user, mineTokenAmount);
        vm.prank(user);
        mineToken.approve(address(bondingCurve), 1e18);

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
}
