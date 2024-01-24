// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { BondingCurveTestBase } from './BondingCurveTestBase.t.sol';
import { IBondingCurve } from '../../../contracts/interfaces/IBondingCurve.sol';
import { TestUtils } from '../utils/TestUtils.t.sol';

contract BondingCurveHarnessTest is BondingCurveTestBase {
    /**
     * ================ getUnitUsdPriceForTimestamp() ================
     */

    function test_getUnitUsdPriceForTimestamp_10Days() public {
        // Arrange
        uint256 currentTimestamp = TestUtils.START_TIMESTAMP + 10 days;
        vm.warp(currentTimestamp);

        // Act
        uint256 price = bondingCurveProxy.exposed_getUnitUsdPriceForTimestamp(block.timestamp);

        // Assert
        uint256 expectedPrice = 1000619095670254662; // 1.000619095670254662
        assertEq(price, expectedPrice);
    }

    function test_getUnitUsdPriceForTimestamp_1Month() public {
        // Arrange
        uint256 currentTimestamp = TestUtils.START_TIMESTAMP + ORACLE_UPDATE_INTERVAL;
        vm.warp(currentTimestamp);

        // Act
        uint256 price = bondingCurveProxy.exposed_getUnitUsdPriceForTimestamp(block.timestamp);

        // Assert
        uint256 expectedPrice = 1001858437086397421; // 1.001858437086397421
        assertEq(price, expectedPrice);
    }

    function test_getUnitUsdPriceForTimestamp_1MonthAnd1Day() public {
        // Arrange
        uint256 currentTimestamp = TestUtils.START_TIMESTAMP + ORACLE_UPDATE_INTERVAL;
        vm.warp(currentTimestamp);
        inflationOracle.setPriceIndexTwentyYearsAgo(78);
        inflationOracle.setLatestPriceIndex(122);
        bondingCurveProxy.updateInternals();

        vm.warp(currentTimestamp + 1 days);

        // Act
        uint256 price = bondingCurveProxy.exposed_getUnitUsdPriceForTimestamp(block.timestamp);

        // Assert
        // IP(t’)               * exp(r(t’) * (t-t’))
        // 1.001858437086397421 * 1.000061262150421502
        uint256 expectedPrice = 1001919813088671258; // 1.001919813088671258
        assertEq(price, expectedPrice);
    }

    function test_getUnitUsdPriceForTimestamp_1MonthAnd1Second() public {
        // Arrange
        uint256 currentTimestamp = TestUtils.START_TIMESTAMP + ORACLE_UPDATE_INTERVAL;
        vm.warp(currentTimestamp);
        inflationOracle.setPriceIndexTwentyYearsAgo(78);
        inflationOracle.setLatestPriceIndex(122);
        bondingCurveProxy.updateInternals();

        vm.warp(currentTimestamp + 1 seconds);

        // Act
        uint256 price = bondingCurveProxy.exposed_getUnitUsdPriceForTimestamp(block.timestamp);

        // Assert
        uint256 expectedPrice = 1001858437796746057; // 1.001858437796746057
        assertEq(price, expectedPrice);
    }

    function test_getUnitUsdPriceForTimestamp_0Days() public {
        // Arrange & Act
        uint256 price = bondingCurveProxy.exposed_getUnitUsdPriceForTimestamp(TestUtils.START_TIMESTAMP);

        // Assert
        uint256 expectedPrice = 1e18;
        assertEq(price, expectedPrice);
    }

    /**
     * ================ updateInternals() ================
     */

    function test_updateInternals() public {
        // Arrange
        uint256 lastInternalPriceBefore = bondingCurveProxy.getUnitUsdPrice();
        uint256 currentTimestamp = TestUtils.START_TIMESTAMP + ORACLE_UPDATE_INTERVAL;
        vm.warp(currentTimestamp);
        uint256 lastOracleUpdateTimestampBefore = bondingCurveProxy.lastOracleUpdateTimestamp();
        inflationOracle.setPriceIndexTwentyYearsAgo(78);
        inflationOracle.setLatestPriceIndex(122);

        // Act
        bondingCurveProxy.updateInternals();

        // Assert
        uint256 lastOracleUpdateTimestampAfter = bondingCurveProxy.lastOracleUpdateTimestamp();
        uint256 lastInternalPriceAfter = bondingCurveProxy.getUnitUsdPrice();
        assertEq(lastInternalPriceBefore, 1e18); // 1
        assertEq(lastInternalPriceAfter, 1001858437086397421); // 1.001858437086397421
        assertEq(bondingCurveProxy.lastOracleInflationRate(), 2236); // 2.236%
        assertGt(lastOracleUpdateTimestampAfter, lastOracleUpdateTimestampBefore);
    }

    /**
     * ================ getReserveRatio() ================
     */

    function test_getReserveRatio_ReturnsRR() public {
        // Arrange & Act
        uint256 reserveRatio = bondingCurveProxy.getReserveRatio();

        // Assert
        assertEq(
            reserveRatio,
            (TestUtils.INITIAL_COLLATERAL_TOKEN_VALUE * TestUtils.RR_PRECISION) / TestUtils.INITIAL_UNIT_VALUE
        );
    }

    /**
     * ================ getExcessCollateralReserve() ================
     */

    function test_getExcessCollateralReserve_ReturnsEE() public {
        // Arrange
        _createUserAndMintUnit(1e18);
        uint256 unitCollateralValue = (unitToken.totalSupply() * bondingCurveProxy.getUnitUsdPrice()) /
            collateralUsdOracle.getCollateralUsdPrice();

        // Act
        uint256 excessCollateral = bondingCurveProxy.getExcessCollateralReserve();

        // Assert
        assertEq(excessCollateral, 999000999001004);
        assertGe(collateralERC20TokenTest.balanceOf(address(bondingCurveProxy)), unitCollateralValue);
    }

    function test_getExcessCollateralReserve_ReturnsZero() public {
        // Arrange
        _createUserAndMintUnit(1e18);
        collateralUsdOracle.setCollateralUsdPrice(1e16);
        uint256 unitCollateralValue = (unitToken.totalSupply() * bondingCurveProxy.getUnitUsdPrice()) /
            collateralUsdOracle.getCollateralUsdPrice();

        // Act
        uint256 excessCollateral = bondingCurveProxy.getExcessCollateralReserve();

        // Assert
        assertEq(excessCollateral, 0);
        assertLt(address(bondingCurveProxy).balance, unitCollateralValue);
    }

    /**
     * ================ quoteMint() ================
     */

    function test_quoteMint_ReturnsQuotes() public {
        // Arrange
        address user = vm.addr(2);
        uint256 collateralAmount = 1e18;
        uint256 userCollateralBalance = 100 * 1e18;
        vm.deal(user, userCollateralBalance);
        vm.warp(TestUtils.START_TIMESTAMP + 10 days);

        // Act
        vm.prank(user);
        uint256 quotes = bondingCurveProxy.quoteMint(collateralAmount);

        // Assert
        assertEq(quotes, 998382904467586844); //0.998382904467586844 UNIT
    }

    function test_quoteMint_ReturnsQuotesFor0Collateral() public {
        // Arrange
        address user = vm.addr(2);
        uint256 userCollateralBalance = 100 * 1e18;
        vm.deal(user, userCollateralBalance);
        vm.warp(TestUtils.START_TIMESTAMP + 10 days);

        // Act
        vm.prank(user);
        uint256 quotes = bondingCurveProxy.quoteMint(0);

        // Assert
        assertEq(quotes, 0);
    }

    function test_quoteMint_RevertWhenReserveRatioBelowHighRR() public {
        // Arrange
        address user = vm.addr(2);
        uint256 collateralAmount = 1e18;
        uint256 userCollateralBalance = 100 * 1e18;
        vm.startPrank(user);
        collateralERC20TokenTest.mint(userCollateralBalance);
        collateralERC20TokenTest.approve(address(bondingCurveProxy), userCollateralBalance);
        vm.stopPrank();

        vm.warp(TestUtils.START_TIMESTAMP + 10 days);

        uint256 bondingCurveCollateralBalance = collateralERC20TokenTest.balanceOf(address(bondingCurveProxy));
        vm.prank(address(bondingCurveProxy));
        collateralERC20TokenTest.burn(bondingCurveCollateralBalance); // remove collateral token form BondingCurve to lower RR

        // Act && Assert
        vm.prank(user);
        vm.expectRevert(IBondingCurve.BondingCurveReserveRatioTooLow.selector);
        bondingCurveProxy.quoteMint(collateralAmount);
    }

    /**
     * ================ quoteBurn() ================
     */

    function test_quoteBurn_ReturnsQuotes() public {
        // Arrange
        uint256 collateralAmount = 1e18;
        address user = _createUserAndMintUnit(collateralAmount);
        uint256 burnAmount = 499191452233793422;

        // Act
        vm.prank(user);
        uint256 quotes = bondingCurveProxy.quoteBurn(burnAmount);

        // Assert
        assertEq(quotes, 499000999000999000);
    }

    function test_quoteBurn_ReturnsQuotesFor0Tokens() public {
        // Arrange
        uint256 collateralAmount = 1e18;
        address user = _createUserAndMintUnit(collateralAmount);

        // Act
        vm.prank(user);
        uint256 quotes = bondingCurveProxy.quoteBurn(0);

        // Assert
        assertEq(quotes, 0);
    }

    /**
     * ================ quoteRedeem() ================
     */

    function test_quoteRedeem_ReturnsQuotes() public {
        // Arrange
        uint256 mineTokenAmount = 1e18;
        address user = _createUserAndMintUnitAndMineTokens(1e18, mineTokenAmount);

        // Act
        vm.prank(user);
        (uint256 userAmount, uint256 burnAmount) = bondingCurveProxy.quoteRedeem(mineTokenAmount);

        // Assert
        assertEq(userAmount, 494505494505496);
        assertEq(burnAmount, 494505494505497);
    }

    function test_quoteRedeem_ReturnsQuotesForZeroAmount() public {
        // Arrange
        uint256 mineTokenAmount = 1e18;
        address user = _createUserAndMintUnitAndMineTokens(1e18, mineTokenAmount);

        // Act
        vm.prank(user);
        (uint256 userAmount, uint256 burnAmount) = bondingCurveProxy.quoteRedeem(0);

        // Assert
        assertEq(userAmount, 0);
        assertEq(burnAmount, 0);
    }
}
