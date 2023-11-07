// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from 'forge-std/Test.sol';
import { BondingCurveTest } from '../contracts/test/BondingCurveTest.sol';
import { InflationOracleTest } from '../contracts/test/InflationOracleTest.sol';
import { EthUsdOracle } from '../contracts/EthUsdOracle.sol';
import { ERC20 } from '../contracts/ERC20.sol';

import { console2 } from 'forge-std/Test.sol';

contract BondingCurveTestTest is Test {
    InflationOracleTest public inflationOracle;
    EthUsdOracle public ethUsdOracle;
    ERC20 public unitToken;
    BondingCurveTest public bondingCurve;
    
    uint256 private constant START_TIMESTAMP = 1699023595;

    function setUp() public {
        vm.warp(START_TIMESTAMP); // set block timestamp
        address wallet = vm.addr(1);
        inflationOracle = new InflationOracleTest();
        inflationOracle.setPriceIndexTwentyYearsAgo(77);
        inflationOracle.setLatestPriceIndex(121);
        ethUsdOracle = new EthUsdOracle();
        unitToken = new ERC20(wallet);
        bondingCurve = new BondingCurveTest(unitToken, inflationOracle, ethUsdOracle);
    }

    function test_getInternalPriceForTimestamp_10days() public {
        uint256 currentTimestamp = START_TIMESTAMP + 10 days;
        vm.warp(currentTimestamp);
        uint256 price = bondingCurve.testGetInternalPriceForTimestamp(block.timestamp);
        uint256 expectedPrice = 1000619095670254662; // 1.000619095670254662
        assertEq(price, expectedPrice);
    }

    function test_getInternalPriceForTimestamp_1month() public {
        assertEq(START_TIMESTAMP, block.timestamp);
    }

    function test_getInternalPriceForTimestamp_0days() public {
        uint256 price = bondingCurve.testGetInternalPriceForTimestamp(START_TIMESTAMP);
        uint256 expectedPrice = 1e18;
        assertEq(price, expectedPrice);
    }
}
