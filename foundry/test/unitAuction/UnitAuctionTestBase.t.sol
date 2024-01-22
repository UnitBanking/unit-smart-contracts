// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Test } from 'forge-std/Test.sol';
import { Proxy } from '../../../contracts/Proxy.sol';
import { UnitAuctionHarness } from '../../../contracts/test/UnitAuctionHarness.sol';
import { Proxiable } from '../../../contracts/abstracts/Proxiable.sol';
import { IBondingCurve } from '../../../contracts/interfaces/IBondingCurve.sol';
import { BondingCurve } from '../../../contracts/BondingCurve.sol';
import { CollateralERC20TokenTest } from '../../../contracts/test/CollateralERC20TokenTest.sol';
import { MineToken } from '../../../contracts/MineToken.sol';
import { UnitToken } from '../../../contracts/UnitToken.sol';
import { InflationOracleHarness } from '../../../contracts/test/InflationOracleHarness.sol';
import { CollateralUsdOracleMock } from '../../../contracts/test/CollateralUsdOracleMock.sol';
import { TestUtils } from '../utils/TestUtils.t.sol';

abstract contract UnitAuctionTestBase is Test {
    uint8 public constant AUCTION_VARIANT_NONE = 1;
    uint8 public constant AUCTION_VARIANT_CONTRACTION = 2;
    uint8 public constant AUCTION_VARIANT_EXPANSION = 3;

    Proxy public proxy;
    UnitAuctionHarness public unitAuctionImplementation;
    UnitAuctionHarness public unitAuctionProxy;
    BondingCurve public bondingCurve;
    CollateralERC20TokenTest public collateralERC20Token;
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
        collateralERC20Token = new CollateralERC20TokenTest();

        // set up Unit token contract
        unitToken = new UnitToken(); // TODO: use Proxy
        unitToken.initialize();

        // set up Mine token contract
        mineToken = new MineToken(); // TODO: use Proxy
        mineToken.initialize();

        // set up oracle contracts
        inflationOracle = new InflationOracleHarness();
        inflationOracle.setPriceIndexTwentyYearsAgo(77);
        inflationOracle.setLatestPriceIndex(121);
        collateralUsdOracle = new CollateralUsdOracleMock();

        // set up BondingCurve contract
        BondingCurve bondingCurveImplementation = new BondingCurve(TestUtils.COLLATERAL_BURN_ADDRESS);
        Proxy _proxy = new Proxy(address(this));

        _proxy.upgradeToAndCall(
            address(bondingCurveImplementation),
            abi.encodeWithSelector(
                IBondingCurve.initialize.selector,
                address(collateralERC20Token),
                address(unitToken),
                address(mineToken),
                inflationOracle,
                collateralUsdOracle
            )
        );
        bondingCurve = BondingCurve(payable(_proxy));

        unitToken.setMinter(address(bondingCurve), true);
        unitToken.setBurner(address(bondingCurve), true);

        mineToken.setMinter(wallet, true);
        mineToken.setBurner(address(bondingCurve), true);

        // send initial collateral token amount to bondingCurveProxy contract
        vm.prank(address(bondingCurve));
        collateralERC20Token.mint(TestUtils.INITIAL_COLLATERAL_TOKEN_VALUE);
        vm.prank(address(bondingCurve));
        unitToken.mint(wallet, TestUtils.INITIAL_UNIT_VALUE);

        // set up UnitAuction contract
        unitAuctionImplementation = new UnitAuctionHarness(bondingCurve, unitToken);
        proxy = new Proxy(address(this));
        proxy.upgradeToAndCall(
            address(unitAuctionImplementation),
            abi.encodeWithSelector(Proxiable.initialize.selector)
        );

        unitAuctionProxy = UnitAuctionHarness(payable(proxy));

        unitToken.setMinter(address(unitAuctionProxy), true);
    }

    function _createUserAndMintUnitAndCollateralToken(uint256 collateralAmount) internal returns (address user) {
        // Arrange
        user = vm.addr(2);
        uint256 userCollateralBalance = 100 * 1e18;
        vm.startPrank(user);
        collateralERC20Token.mint(userCollateralBalance);
        collateralERC20Token.approve(address(bondingCurve), userCollateralBalance);
        collateralERC20Token.approve(address(unitAuctionProxy), userCollateralBalance);
        vm.stopPrank();

        vm.warp(TestUtils.START_TIMESTAMP + 10 days);

        // Act
        vm.prank(user);
        bondingCurve.mint(user, collateralAmount);
    }
}
