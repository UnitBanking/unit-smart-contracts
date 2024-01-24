// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

library ReserveRatio {
    uint256 public constant RR_PRECISION = 1e18; // Has to be >= UNIT token precision (i.e. 10 ** UNIT.decimals())

    uint256 public constant CRITICAL_RR = 1 * RR_PRECISION;
    uint256 public constant LOW_RR = 3 * RR_PRECISION;
    uint256 public constant HIGH_RR = 4 * RR_PRECISION;
    uint256 public constant TARGET_RR = 5 * RR_PRECISION;
}
