// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Test } from 'forge-std/Test.sol';

import { BondingCurve } from '../../contracts/BondingCurve.sol';
import { BondingCurveHarness } from '../../contracts/test/BondingCurveHarness.sol';
import { MineToken } from '../../contracts/MineToken.sol';
import { UnitToken } from '../../contracts/UnitToken.sol';
import { CollateralERC20TokenTest } from '../../contracts/test/CollateralERC20TokenTest.sol';
import { InflationOracleHarness } from '../../contracts/test/InflationOracleHarness.sol';
import { CollateralUsdOracleMock } from '../../contracts/test/CollateralUsdOracleMock.sol';
import { Proxy } from '../../contracts/Proxy.sol';
import { Proxiable } from '../../contracts/abstracts/Proxiable.sol';

import { TestUtils } from './utils/TestUtils.t.sol';

enum BondingCurveType {
    Production,
    Test
}

abstract contract TestBase is Test {
    UnitToken public unitToken;
    MineToken public mineToken;
    CollateralERC20TokenTest public collateralToken;
    InflationOracleHarness public inflationOracle;
    CollateralUsdOracleMock public collateralUsdOracle;

    address public wallet = vm.addr(1);

    function _setUp(
        BondingCurveType bcType,
        uint8 collateralDecimals
    ) public returns (address bondingCurveImplementation, address bondingCurveProxy) {
        // set up wallet balance
        vm.deal(wallet, 10 ether);

        // set up block timestamp
        vm.warp(TestUtils.START_TIMESTAMP);

        // set up Unit token contract
        unitToken = new UnitToken(); // TODO: use Proxy
        unitToken.initialize();

        // set up Mine token contract
        mineToken = new MineToken(); // TODO: use Proxy
        mineToken.initialize();

        // set up collateral token
        collateralToken = new CollateralERC20TokenTest(collateralDecimals);

        // set up oracle contracts
        inflationOracle = new InflationOracleHarness();
        inflationOracle.setPriceIndexTwentyYearsAgo(77);
        inflationOracle.setLatestPriceIndex(121);
        collateralUsdOracle = new CollateralUsdOracleMock();

        // set up BondingCurve contract
        if (bcType == BondingCurveType.Production) {
            bondingCurveImplementation = address(
                new BondingCurve(
                    unitToken,
                    mineToken,
                    collateralToken,
                    TestUtils.COLLATERAL_BURN_ADDRESS,
                    inflationOracle,
                    collateralUsdOracle
                )
            );
        } else if (bcType == BondingCurveType.Test) {
            bondingCurveImplementation = address(
                new BondingCurveHarness(
                    unitToken,
                    mineToken,
                    collateralToken,
                    TestUtils.COLLATERAL_BURN_ADDRESS,
                    inflationOracle,
                    collateralUsdOracle
                )
            );
        } else {
            revert('Invalid bonding curve contract type');
        }
        bondingCurveProxy = address(new Proxy(address(this)));
        Proxy(payable(bondingCurveProxy)).upgradeToAndCall(
            address(bondingCurveImplementation),
            abi.encodeWithSelector(Proxiable.initialize.selector)
        );

        unitToken.setMinter(address(bondingCurveProxy), true);
        unitToken.setBurner(address(bondingCurveProxy), true);

        mineToken.setMinter(wallet, true);
        mineToken.setBurner(address(bondingCurveProxy), true);

        // send initial collateral token amount to bondingCurveProxy contract
        vm.prank(address(bondingCurveProxy));
        collateralToken.mint(TestUtils.INITIAL_COLLATERAL_TOKEN_VALUE);
        vm.prank(address(bondingCurveProxy));
        unitToken.mint(wallet, TestUtils.INITIAL_UNIT_VALUE);
    }
}
