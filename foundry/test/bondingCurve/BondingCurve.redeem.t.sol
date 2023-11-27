// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { Test, stdError } from 'forge-std/Test.sol';
import { BondingCurveHelper } from './BondingCurveHelper.t.sol';
import { BondingCurveHarness } from '../../../contracts/test/BondingCurveHarness.sol';
import { InflationOracleTest } from '../../../contracts/test/InflationOracleTest.sol';
import { EthUsdOracle } from '../../../contracts/EthUsdOracle.sol';
import { ERC20 } from '../../../contracts/ERC20.sol';
import { IBondingCurve } from '../../../contracts/interfaces/IBondingCurve.sol';

contract BondingCurveRedeemTest is Test, BondingCurveHelper {
    address public wallet = vm.addr(1);

    function setUp() public {
        // set up wallet balance
        vm.deal(wallet, 10 ether);

        // set up block timestamp
        vm.warp(START_TIMESTAMP);

        // set up oracle contracts
        inflationOracle = new InflationOracleTest();
        inflationOracle.setPriceIndexTwentyYearsAgo(77);
        inflationOracle.setLatestPriceIndex(121);
        ethUsdOracle = new EthUsdOracle();

        // set up Unit token contract
        unitToken = new ERC20(wallet);
        // set up Mine token contract
        mineToken = new ERC20(wallet);

        // set up BondingCurve contract
        bondingCurve = new BondingCurveHarness(address(unitToken), address(mineToken), inflationOracle, ethUsdOracle);
        vm.startPrank(wallet);
        unitToken.setMinter(address(bondingCurve));
        mineToken.setMinter(wallet);
        payable(address(bondingCurve)).transfer(INITIAL_ETH_VALUE);
        vm.stopPrank();
        vm.prank(address(bondingCurve));
        unitToken.mint(wallet, INITIAL_UNIT_VALUE);
    }

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

    /**
     * ================ mint fixture ================
     */

    function _createUserAndMintUnit(uint256 etherValue) private returns (address user) {
        // Arrange
        user = vm.addr(2);
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);

        // Act
        vm.prank(user);
        bondingCurve.mint{ value: etherValue }(user);

        return user;
    }

    function _mintMineToken(address receiver, uint256 value) private {
        vm.prank(wallet);
        mineToken.mint(receiver, value);
    }
}
