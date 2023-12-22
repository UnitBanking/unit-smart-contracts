// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { Test } from 'forge-std/Test.sol';
import { BondingCurveHarness } from '../../../contracts/test/BondingCurveHarness.sol';
import { InflationOracleHarness } from '../../../contracts/test/InflationOracleHarness.sol';
import { EthUsdOracleMock } from '../../../contracts/test/EthUsdOracleMock.sol';
import { IBondingCurve } from '../../../contracts/interfaces/IBondingCurve.sol';
import { MineToken } from '../../../contracts/MineToken.sol';
import { UnitToken } from '../../../contracts/UnitToken.sol';
import { Proxy } from '../../../contracts/Proxy.sol';

abstract contract BondingCurveTestBase is Test {
    uint256 internal constant ORACLE_UPDATE_INTERVAL = 30 days;
    uint256 internal constant START_TIMESTAMP = 1699023595;
    uint256 internal constant INITIAL_ETH_VALUE = 5 wei;
    uint256 internal constant INITIAL_UNIT_VALUE = 1 wei;
    uint256 internal constant HIGH_RR = 4;

    InflationOracleHarness public inflationOracle;
    EthUsdOracleMock public ethUsdOracle;
    UnitToken public unitToken;
    MineToken public mineToken;

    Proxy public bondingCurveProxyType;
    BondingCurveHarness public bondingCurveImplementation;
    BondingCurveHarness public bondingCurveProxy;

    address public wallet = vm.addr(1);

    function setUp() public {
        // set up wallet balance
        vm.deal(wallet, 10 ether);

        // set up block timestamp
        vm.warp(START_TIMESTAMP);

        // set up oracle contracts
        inflationOracle = new InflationOracleHarness();
        inflationOracle.setPriceIndexTwentyYearsAgo(77);
        inflationOracle.setLatestPriceIndex(121);
        ethUsdOracle = new EthUsdOracleMock();

        // set up Unit token contract
        unitToken = new UnitToken(); // TODO: use Proxy
        unitToken.initialize();
        // set up Mine token contract
        mineToken = new MineToken(); // TODO: use Proxy
        mineToken.initialize();

        // set up BondingCurve contract
        bondingCurveImplementation = new BondingCurveHarness();
        bondingCurveProxyType = new Proxy(address(this));

        bondingCurveProxyType.upgradeToAndCall(
            address(bondingCurveImplementation),
            abi.encodeWithSelector(
                IBondingCurve.initialize.selector,
                address(unitToken),
                address(mineToken),
                inflationOracle,
                ethUsdOracle
            )
        );

        bondingCurveProxy = BondingCurveHarness(payable(bondingCurveProxyType));

        unitToken.setMinter(address(bondingCurveProxy), true);
        unitToken.setBurner(address(bondingCurveProxy), true);
        mineToken.setMinter(wallet, true);
        mineToken.setBurner(address(bondingCurveProxy), true);

        vm.startPrank(wallet);
        payable(address(bondingCurveProxy)).transfer(INITIAL_ETH_VALUE);
        vm.stopPrank();
        vm.prank(address(bondingCurveProxy));
        unitToken.mint(wallet, INITIAL_UNIT_VALUE);
    }

    function _createUserAndMintUnit(uint256 collateralAmountIn) internal returns (address user) {
        // Arrange
        user = vm.addr(2);
        uint256 userEthBalance = 100 ether;
        vm.deal(user, userEthBalance);
        vm.warp(START_TIMESTAMP + 10 days);

        // Act
        vm.prank(user);
        bondingCurveProxy.mint(user, collateralAmountIn);

        return user;
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
