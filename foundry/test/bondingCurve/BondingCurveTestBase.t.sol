// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { Test } from 'forge-std/Test.sol';
import { BondingCurveHarness } from '../../../contracts/test/BondingCurveHarness.sol';
import { InflationOracleHarness } from '../../../contracts/test/InflationOracleHarness.sol';
import { EthUsdOracleMock } from '../../../contracts/test/EthUsdOracleMock.sol';
import { MineToken } from '../../../contracts/MineToken.sol';
import { UnitToken } from '../../../contracts/UnitToken.sol';

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

    BondingCurveHarness public bondingCurve;

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
        bondingCurve = new BondingCurveHarness(address(unitToken), address(mineToken), inflationOracle, ethUsdOracle);
        unitToken.setMinter(address(bondingCurve), true);
        unitToken.setBurner(address(bondingCurve), true);
        mineToken.setMinter(wallet, true);
        mineToken.setBurner(address(bondingCurve), true);
        
        vm.startPrank(wallet);
        payable(address(bondingCurve)).transfer(INITIAL_ETH_VALUE);
        vm.stopPrank();
        vm.prank(address(bondingCurve));
        unitToken.mint(wallet, INITIAL_UNIT_VALUE);
    }

    function _createUserAndMintUnit(uint256 etherValue) internal returns (address user) {
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

    function _mintMineToken(address receiver, uint256 value) internal {
        vm.prank(wallet);
        mineToken.mint(receiver, value);
    }

    function _createUserAndMintUnitAndMineTokens(
        uint256 etherValue,
        uint256 mineTokenAmount
    ) internal returns (address user) {
        user = _createUserAndMintUnit(etherValue);
        _mintMineToken(user, mineTokenAmount);
    }
}
