// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Test } from 'forge-std/Test.sol';
import { BondingCurveHarness } from '../../../contracts/test/BondingCurveHarness.sol';
import { InflationOracleHarness } from '../../../contracts/test/InflationOracleHarness.sol';
import { CollateralUsdOracleMock } from '../../../contracts/test/CollateralUsdOracleMock.sol';
import { CollateralERC20TokenTest } from '../../../contracts/test/CollateralERC20TokenTest.sol';
import { Proxiable } from '../../../contracts/abstracts/Proxiable.sol';
import { MineToken } from '../../../contracts/MineToken.sol';
import { UnitToken } from '../../../contracts/UnitToken.sol';
import { Proxy } from '../../../contracts/Proxy.sol';
import { TestUtils } from '../utils/TestUtils.t.sol';

abstract contract BondingCurveTestBase is Test {
    uint256 internal constant ORACLE_UPDATE_INTERVAL = 30 days;

    BondingCurveHarness public bondingCurveImplementation;
    BondingCurveHarness public bondingCurveProxy;

    CollateralERC20TokenTest public collateralToken;
    UnitToken public unitToken;
    MineToken public mineToken;
    InflationOracleHarness public inflationOracle;
    CollateralUsdOracleMock public collateralUsdOracle;

    address public wallet = vm.addr(1);

    function setUp() public {
        // set up wallet balance
        vm.deal(wallet, 10 ether);

        // set up block timestamp
        vm.warp(TestUtils.START_TIMESTAMP);

        // set up collateral token
        collateralToken = new CollateralERC20TokenTest();

        // set up oracle contracts
        inflationOracle = new InflationOracleHarness();
        inflationOracle.setPriceIndexTwentyYearsAgo(77);
        inflationOracle.setLatestPriceIndex(121);
        collateralUsdOracle = new CollateralUsdOracleMock();

        // set up Unit token contract
        unitToken = new UnitToken(); // TODO: use Proxy
        unitToken.initialize();
        // set up Mine token contract
        mineToken = new MineToken(); // TODO: use Proxy
        mineToken.initialize();

        // set up BondingCurve contract
        bondingCurveImplementation = new BondingCurveHarness(
            unitToken,
            mineToken,
            collateralToken,
            TestUtils.COLLATERAL_BURN_ADDRESS,
            inflationOracle,
            collateralUsdOracle
        );
        Proxy proxy = new Proxy(address(this));
        proxy.upgradeToAndCall(
            address(bondingCurveImplementation),
            abi.encodeWithSelector(Proxiable.initialize.selector)
        );
        bondingCurveProxy = BondingCurveHarness(payable(proxy));

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

    function _createUserAndMintUnit(uint256 collateralAmountIn) internal returns (address user) {
        // Arrange
        user = vm.addr(2);
        uint256 userCollateralBalance = 100 * 1e18;
        vm.startPrank(user);
        collateralToken.mint(userCollateralBalance);
        collateralToken.approve(address(bondingCurveProxy), userCollateralBalance);
        vm.stopPrank();

        vm.warp(TestUtils.START_TIMESTAMP + 10 days);

        // Act
        vm.prank(user);
        bondingCurveProxy.mint(user, collateralAmountIn);
    }

    function _mintMineToken(address receiver, uint256 value) internal {
        vm.prank(wallet);
        mineToken.mint(receiver, value);
    }

    function _createUserAndMintUnitAndMineTokens(
        uint256 collateralAmount,
        uint256 mineTokenAmount
    ) internal returns (address user) {
        user = _createUserAndMintUnit(collateralAmount);
        _mintMineToken(user, mineTokenAmount);
    }
}
