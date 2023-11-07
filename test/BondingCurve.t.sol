// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from 'forge-std/Test.sol';
import { BondingCurveTest } from '../contracts/test/BondingCurveTest.sol';
import { InflationOracle } from '../contracts/InflationOracle.sol';
import { EthUsdOracle } from '../contracts/EthUsdOracle.sol';
import { ERC20 } from '../contracts/ERC20.sol';

import { console2 } from 'forge-std/Test.sol';

contract BondingCurveTestTest is Test {
    InflationOracle public inflationOracle;
    EthUsdOracle public ethUsdOracle;
    ERC20 public unitToken;
    BondingCurveTest public bondingCurve;

    function setUp() public {
        vm.warp(1699023595); // set block.timestamp
        address wallet = vm.addr(1);
        inflationOracle = new InflationOracle();
        ethUsdOracle = new EthUsdOracle();
        unitToken = new ERC20(wallet);
        bondingCurve = new BondingCurveTest(unitToken, inflationOracle, ethUsdOracle);
    }

    function test_getInternalPriceForTimestamp() public {
        vm.warp(1799023595); // set block.timestamp
        uint256 price = bondingCurve.testGetInternalPriceForTimestamp(block.timestamp);
        console2.log('[DEBUG]', price);
    }
}
