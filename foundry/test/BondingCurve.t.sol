// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { Test, stdError } from 'forge-std/Test.sol';
import { BondingCurveHarness } from '../../contracts/test/BondingCurveHarness.sol';
import { InflationOracleTest } from '../../contracts/test/InflationOracleTest.sol';
import { EthUsdOracle } from '../../contracts/EthUsdOracle.sol';
import { ERC20 } from '../../contracts/ERC20.sol';
import { IBondingCurve } from '../../contracts/interfaces/IBondingCurve.sol';

import { console } from 'forge-std/Test.sol';

contract BondingCurveHarnessTest is Test {
    InflationOracleTest public inflationOracle;
    EthUsdOracle public ethUsdOracle;
    ERC20 public unitToken;
    ERC20 public mineToken;
    BondingCurveHarness public bondingCurve;
    address public wallet = vm.addr(1);

    uint256 private constant ORACLE_UPDATE_INTERVAL = 30 days;
    uint256 private constant START_TIMESTAMP = 1699023595;
    uint256 private constant INITIAL_ETH_VALUE = 5 wei;
    uint256 private constant INITIAL_UNIT_VALUE = 1 wei;
    uint256 private constant HIGH_RR = 4;

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
        mineToken = new ERC20(wallet);

        // set up BondingCurve contract
        bondingCurve = new BondingCurveHarness(address(unitToken), address(mineToken), inflationOracle, ethUsdOracle);
        vm.startPrank(wallet);
        unitToken.setMinter(address(bondingCurve));
        payable(address(bondingCurve)).transfer(INITIAL_ETH_VALUE);
        vm.stopPrank();
        vm.prank(address(bondingCurve));
        unitToken.mint(wallet, INITIAL_UNIT_VALUE);
    }

    /**
     * ================ getInternalPriceForTimestamp() ================
     */

    function test_getInternalPriceForTimestamp_10Days() public {
        // Arrange
        uint256 currentTimestamp = START_TIMESTAMP + 10 days;
        vm.warp(currentTimestamp);

        // Act
        uint256 price = bondingCurve.exposed_GetInternalPriceForTimestamp(block.timestamp);

        // Assert
        uint256 expectedPrice = 1000619095670254662; // 1.000619095670254662
        assertEq(price, expectedPrice);
    }

    function test_getInternalPriceForTimestamp_1Month() public {
        // Arrange
        uint256 currentTimestamp = START_TIMESTAMP + ORACLE_UPDATE_INTERVAL;
        vm.warp(currentTimestamp);

        // Act
        uint256 price = bondingCurve.exposed_GetInternalPriceForTimestamp(block.timestamp);

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
        uint256 price = bondingCurve.exposed_GetInternalPriceForTimestamp(block.timestamp);

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
        uint256 price = bondingCurve.exposed_GetInternalPriceForTimestamp(block.timestamp);

        // Assert
        uint256 expectedPrice = 1001858437796746057; // 1.001858437796746057
        assertEq(price, expectedPrice);
    }

    function test_getInternalPriceForTimestamp_0Days() public {
        // Arrange & Act
        uint256 price = bondingCurve.exposed_GetInternalPriceForTimestamp(START_TIMESTAMP);

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

    /**
     * ================ burn() ================
     */

    function test_burn_SuccessfullyBurnsUnitToken() public {
        // Arrange
        uint256 etherValue = 1 ether;
        address user = _createUserAndMint(etherValue);
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
        address user = _createUserAndMint(etherValue);
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
        address user = _createUserAndMint(etherValue);
        uint256 additionalUnitAmount = 1;
        uint256 burnAmount = unitToken.balanceOf(user) + additionalUnitAmount;
        vm.prank(user);
        unitToken.approve(address(bondingCurve), burnAmount);
        vm.prank(address(bondingCurve));
        unitToken.mint(wallet, additionalUnitAmount);

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(stdError.arithmeticError);
        bondingCurve.burn(burnAmount);
    }

    function test_burn_RevertsIfUserTriesToBurnMoreThanUnitTotalSupply() public {
        // Arrange
        uint256 etherValue = 1 ether;
        address user = _createUserAndMint(etherValue);
        uint256 burnAmount = unitToken.totalSupply() + 1;
        vm.prank(user);
        unitToken.approve(address(bondingCurve), burnAmount);

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(stdError.arithmeticError);
        bondingCurve.burn(burnAmount);
    }

    /**
     * ================ getReserveRatio() ================
     */

    function test_getReserveRatio_ReturnsRR() public {
        // Arrange & Act
        uint256 reserveRatio = bondingCurve.getReserveRatio();

        // Assert
        assertEq(reserveRatio, INITIAL_ETH_VALUE / INITIAL_UNIT_VALUE);
    }

    /**
     * ================ getExcessEthReserve() ================
     */

    function test_getExcessEthReserve_ReturnsEE() public {
        // Arrange
        _createUserAndMint(1 ether);

        // Act
        uint256 excessEth = bondingCurve.getExcessEthReserve();

        // Assert
        assertEq(excessEth, 999000999001004);
    }

    /**
     * ================ mint fixture ================
     */

    function _createUserAndMint(uint256 etherValue) private returns (address user) {
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
}