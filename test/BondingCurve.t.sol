// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from 'forge-std/Test.sol';
import { BondingCurveTest } from '../contracts/test/BondingCurveTest.sol';
import { InflationOracleTest } from '../contracts/test/InflationOracleTest.sol';
import { EthUsdOracle } from '../contracts/EthUsdOracle.sol';
import '../contracts/Errors.sol';
import { ERC20 } from '../contracts/ERC20.sol';

import { console2 } from 'forge-std/Test.sol';

contract BondingCurveTestTest is Test {
    InflationOracleTest public inflationOracle;
    EthUsdOracle public ethUsdOracle;
    ERC20 public unitToken;
    BondingCurveTest public bondingCurve;
    address wallet = vm.addr(1);

    uint256 private constant ORACLE_UPDATE_INTERVAL = 30 days;
    uint256 private constant START_TIMESTAMP = 1699023595;

    function setUp() public {
        vm.deal(wallet, 10 ether);
        vm.warp(START_TIMESTAMP); // set block timestamp
        inflationOracle = new InflationOracleTest();
        inflationOracle.setPriceIndexTwentyYearsAgo(77);
        inflationOracle.setLatestPriceIndex(121);
        ethUsdOracle = new EthUsdOracle();
        unitToken = new ERC20(wallet);
        bondingCurve = new BondingCurveTest(unitToken, inflationOracle, ethUsdOracle);
        vm.prank(wallet);
        unitToken.setMinter(address(bondingCurve));
    }

    /**
     * ================ getInternalPriceForTimestamp() ================
     */

    function test_getInternalPriceForTimestamp_10Days() public {
        // Arrange
        uint256 currentTimestamp = START_TIMESTAMP + 10 days;
        vm.warp(currentTimestamp);

        // Act
        uint256 price = bondingCurve.testGetInternalPriceForTimestamp(block.timestamp);

        // Assert
        uint256 expectedPrice = 1000619095670254662; // 1.000619095670254662
        assertEq(price, expectedPrice);
    }

    function test_getInternalPriceForTimestamp_1Month() public {
        // Arrange
        uint256 currentTimestamp = START_TIMESTAMP + ORACLE_UPDATE_INTERVAL;
        vm.warp(currentTimestamp);

        // Act
        uint256 price = bondingCurve.testGetInternalPriceForTimestamp(block.timestamp);

        // Assert
        uint256 expectedPrice = 1001858437086397421; // 1.001858437086397421
        assertEq(price, expectedPrice);
    }

    function test_getInternalPriceForTimestamp_1MonthAnd1Day() public {
        // Arrange
        uint256 currentTimestamp = START_TIMESTAMP + ORACLE_UPDATE_INTERVAL;
        vm.warp(currentTimestamp);
        inflationOracle.setPriceIndexTwentyYearsAgo(78);
        inflationOracle.setLatestPriceIndex(122);
        bondingCurve.updateInternals();

        vm.warp(currentTimestamp + 1 days);

        // Act
        uint256 price = bondingCurve.testGetInternalPriceForTimestamp(block.timestamp);

        // Assert
        // IP(t’)               * exp(r(t’) * (t-t’))
        // 1.001858437086397421 * 1.000061262150421502
        uint256 expectedPrice = 1001919813088671258; // 1.001919813088671258
        assertEq(price, expectedPrice);
    }

    function test_getInternalPriceForTimestamp_1MonthAnd1Second() public {
        // Arrange
        uint256 currentTimestamp = START_TIMESTAMP + ORACLE_UPDATE_INTERVAL;
        vm.warp(currentTimestamp);
        inflationOracle.setPriceIndexTwentyYearsAgo(78);
        inflationOracle.setLatestPriceIndex(122);
        bondingCurve.updateInternals();

        vm.warp(currentTimestamp + 1 seconds);

        // Act
        uint256 price = bondingCurve.testGetInternalPriceForTimestamp(block.timestamp);

        // Assert
        uint256 expectedPrice = 1001858437796746057; // 1.001858437796746057
        assertEq(price, expectedPrice);
    }

    function test_getInternalPriceForTimestamp_0Days() public {
        // Arrange & Act
        uint256 price = bondingCurve.testGetInternalPriceForTimestamp(START_TIMESTAMP);

        // Assert
        uint256 expectedPrice = 1e18;
        assertEq(price, expectedPrice);
    }

    /**
     * ================ updateInternals() ================
     */

    function test_updateInternals() public {
        // Arrange
        uint256 lastInternalPriceBefore = bondingCurve.getInternalPrice();
        uint256 currentTimestamp = START_TIMESTAMP + ORACLE_UPDATE_INTERVAL;
        vm.warp(currentTimestamp);
        uint256 lastOracleUpdateTimestampBefore = bondingCurve.lastOracleUpdateTimestamp();
        inflationOracle.setPriceIndexTwentyYearsAgo(78);
        inflationOracle.setLatestPriceIndex(122);

        // Act
        bondingCurve.updateInternals();

        // Assert
        uint256 lastOracleUpdateTimestampAfter = bondingCurve.lastOracleUpdateTimestamp();
        uint256 lastInternalPriceAfter = bondingCurve.getInternalPrice();
        assertEq(lastInternalPriceBefore, 1e18); // 1
        assertEq(lastInternalPriceAfter, 1001858437086397421); // 1.001858437086397421
        assertEq(bondingCurve.lastOracleInflationRate(), 2236); // 2.236%
        assertGt(lastOracleUpdateTimestampAfter, lastOracleUpdateTimestampBefore);
    }

    /**
     * ================ mint() ================
     */

    function test_mint_SuccessfullyMintUnitToken() public {
        // Arrange
        address user = vm.addr(2);
        uint256 etherValue = 1 ether;
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);
        setUpReserveRatio();
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

    function test_mint_SendZeroEth() public {
        // Arrange
        address user = vm.addr(2);
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);
        setUpReserveRatio();

        // Act
        vm.prank(user);
        bondingCurve.mint{ value: 0 }(user);

        // Assert
        assertEq(user.balance, userEthBalance);
        assertEq(unitToken.balanceOf(user), 0);
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
        vm.expectRevert(InvalidReceiver.selector);
        bondingCurve.mint{ value: etherValue }(address(0));

        assertEq(user.balance, userEthBalance);
    }

    function test_mint_RevertWhenReserveRatioBelowHighRR() public {
        // Arrange
        address user = vm.addr(2);
        uint256 etherValue = 1 ether;
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);

        // Act && Assert
        vm.prank(user);
        vm.expectRevert(MintDisabledDueToTooLowRR.selector);
        bondingCurve.mint{ value: etherValue }(user);
        assertEq(user.balance, userEthBalance);
    }

    /**
     * ================ getReserveRatio() ================
     */

    function test_getReserveRatio_ReturnsRR() public {
        uint256 reserveRatio = bondingCurve.getReserveRatio();
        assertEq(reserveRatio, 0);
    }

    function setUpReserveRatio() internal {
        // setup RR
        vm.prank(wallet);
        payable(address(bondingCurve)).transfer(5 wei);
        vm.prank(address(bondingCurve));
        unitToken.mint(wallet, 1);
    }
}
