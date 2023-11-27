// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { BondingCurveHarness } from '../../../contracts/test/BondingCurveHarness.sol';
import { InflationOracleTest } from '../../../contracts/test/InflationOracleTest.sol';
import { EthUsdOracle } from '../../../contracts/EthUsdOracle.sol';
import { ERC20 } from '../../../contracts/ERC20.sol';
import { IBondingCurve } from '../../../contracts/interfaces/IBondingCurve.sol';

abstract contract BondingCurveHelper {
    uint256 internal constant ORACLE_UPDATE_INTERVAL = 30 days;
    uint256 internal constant START_TIMESTAMP = 1699023595;
    uint256 internal constant INITIAL_ETH_VALUE = 5 wei;
    uint256 internal constant INITIAL_UNIT_VALUE = 1 wei;
    uint256 internal constant HIGH_RR = 4;

    InflationOracleTest public inflationOracle;
    EthUsdOracle public ethUsdOracle;
    ERC20 public unitToken;
    ERC20 public mineToken;

    BondingCurveHarness public bondingCurve;
}
