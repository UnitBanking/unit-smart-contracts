// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { BondingCurveTestBase } from './BondingCurveTestBase.t.sol';
import { IBondingCurve } from '../../../contracts/interfaces/IBondingCurve.sol';

contract BondingCurveHarnessTest is BondingCurveTestBase {
    /**
     * ================ getUnitUsdPriceForTimestamp() ================
     */

    function test_getUnitUsdPriceForTimestamp_10Days() public {
        // Arrange
        uint256 currentTimestamp = START_TIMESTAMP + 10 days;
        vm.warp(currentTimestamp);

        // Act
        uint256 price = bondingCurveProxy.exposed_getUnitUsdPriceForTimestamp(block.timestamp);

        // Assert
        uint256 expectedPrice = 1000619095670254662; // 1.000619095670254662
        assertEq(price, expectedPrice);
    }

    function test_getUnitUsdPriceForTimestamp_1Month() public {
        // Arrange
        uint256 currentTimestamp = START_TIMESTAMP + ORACLE_UPDATE_INTERVAL;
        vm.warp(currentTimestamp);

        // Act
        uint256 price = bondingCurveProxy.exposed_getUnitUsdPriceForTimestamp(block.timestamp);

        // Assert
        uint256 expectedPrice = 1001858437086397421; // 1.001858437086397421
        assertEq(price, expectedPrice);
    }

    function test_getUnitUsdPriceForTimestamp_1MonthAnd1Day() public {
        // Arrange
        uint256 currentTimestamp = START_TIMESTAMP + ORACLE_UPDATE_INTERVAL;
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
        uint256 currentTimestamp = START_TIMESTAMP + ORACLE_UPDATE_INTERVAL;
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
        uint256 price = bondingCurveProxy.exposed_getUnitUsdPriceForTimestamp(START_TIMESTAMP);

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
        uint256 currentTimestamp = START_TIMESTAMP + ORACLE_UPDATE_INTERVAL;
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
        assertEq(reserveRatio, INITIAL_ETH_VALUE / INITIAL_UNIT_VALUE);
    }

    /**
     * ================ getExcessEthReserve() ================
     */

    function test_getExcessEthReserve_ReturnsEE() public {
        // Arrange
        _createUserAndMintUnit(1 ether);
        uint256 unitEthValue = (unitToken.totalSupply() * bondingCurveProxy.getUnitUsdPrice()) /
            ethUsdOracle.getEthUsdPrice();

        // Act
        uint256 excessEth = bondingCurveProxy.getExcessEthReserve();

        // Assert
        assertEq(excessEth, 999000999001004);
        assertGe(address(bondingCurveProxy).balance, unitEthValue);
    }

    function test_getExcessEthReserve_ReturnsZero() public {
        // Arrange
        _createUserAndMintUnit(1 ether);
        ethUsdOracle.setEthUsdPrice(1e16);
        uint256 unitEthValue = (unitToken.totalSupply() * bondingCurveProxy.getUnitUsdPrice()) /
            ethUsdOracle.getEthUsdPrice();

        // Act
        uint256 excessEth = bondingCurveProxy.getExcessEthReserve();

        // Assert
        assertEq(excessEth, 0);
        assertLt(address(bondingCurveProxy).balance, unitEthValue);
    }

    /**
     * ================ quoteMint() ================
     */

    function test_quoteMint_ReturnsQuotes() public {
        // Arrange
        address user = vm.addr(2);
        uint256 collateralAmount = 1 ether;
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);

        // Act
        vm.prank(user);
        uint256 quotes = bondingCurveProxy.quoteMint(collateralAmount);

        // Assert
        assertEq(quotes, 998382904467586844); //0.998382904467586844 UNIT
    }

    function test_quoteMint_ReturnsQuotesFor0Eth() public {
        // Arrange
        address user = vm.addr(2);
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);

        // Act
        vm.prank(user);
        uint256 quotes = bondingCurveProxy.quoteMint(0);

        // Assert
        assertEq(quotes, 0);
    }

    function test_quoteMint_RevertWhenReserveRatioBelowHighRR() public {
        // Arrange
        address user = vm.addr(2);
        uint256 collateralAmount = 1 ether;
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);
        vm.prank(address(bondingCurveProxy));
        payable(address(0)).transfer(address(bondingCurveProxy).balance); // remove ETH form BondingCurve to lower RR

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
        uint256 collateralAmount = 1 ether;
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
        uint256 collateralAmount = 1 ether;
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
        address user = _createUserAndMintUnitAndMineTokens(1 ether, mineTokenAmount);

        // Act
        vm.prank(user);
        (uint256 userAmount, uint256 burnAmount) = bondingCurveProxy.quoteRedeem(mineTokenAmount);

        // Assert
        assertEq(userAmount, 494505494505496);
        assertEq(burnAmount, 494505494505497);
    }

    function test_quoteRedeem_ReturnsQuotesFor0Token() public {
        // Arrange
        uint256 mineTokenAmount = 1e18;
        address user = _createUserAndMintUnitAndMineTokens(1 ether, mineTokenAmount);

        // Act
        vm.prank(user);
        (uint256 userAmount, uint256 burnAmount) = bondingCurveProxy.quoteRedeem(0);

        // Assert
        assertEq(userAmount, 0);
        assertEq(burnAmount, 0);
    }
}
