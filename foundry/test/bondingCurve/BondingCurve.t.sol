// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { BondingCurveTestBase } from './BondingCurveHelper.t.sol';

contract BondingCurveHarnessTest is BondingCurveTestBase {
    /**
     * ================ getInternalPriceForTimestamp() ================
     */

    function test_getInternalPriceForTimestamp_10Days() public {
        // Arrange
        uint256 currentTimestamp = START_TIMESTAMP + 10 days;
        vm.warp(currentTimestamp);

        // Act
        uint256 price = bondingCurve.exposed_getInternalPriceForTimestamp(block.timestamp);

        // Assert
        uint256 expectedPrice = 1000619095670254662; // 1.000619095670254662
        assertEq(price, expectedPrice);
    }

    function test_getInternalPriceForTimestamp_1Month() public {
        // Arrange
        uint256 currentTimestamp = START_TIMESTAMP + ORACLE_UPDATE_INTERVAL;
        vm.warp(currentTimestamp);

        // Act
        uint256 price = bondingCurve.exposed_getInternalPriceForTimestamp(block.timestamp);

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
        uint256 price = bondingCurve.exposed_getInternalPriceForTimestamp(block.timestamp);

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
        uint256 price = bondingCurve.exposed_getInternalPriceForTimestamp(block.timestamp);

        // Assert
        uint256 expectedPrice = 1001858437796746057; // 1.001858437796746057
        assertEq(price, expectedPrice);
    }

    function test_getInternalPriceForTimestamp_0Days() public {
        // Arrange & Act
        uint256 price = bondingCurve.exposed_getInternalPriceForTimestamp(START_TIMESTAMP);

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
        _createUserAndMintUnit(1 ether);

        // Act
        uint256 excessEth = bondingCurve.getExcessEthReserve();

        // Assert
        assertEq(excessEth, 999000999001004);
    }
}
