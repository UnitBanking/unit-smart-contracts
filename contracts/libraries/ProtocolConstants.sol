// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

library ProtocolConstants {
    uint256 public constant STANDARD_PRECISION = 1e18; // Must equal UNIT token precision

    // Reserve ratio (RR) constants
    uint256 public constant CRITICAL_RR = 1 * STANDARD_PRECISION;
    uint256 public constant LOW_RR = 3 * STANDARD_PRECISION;
    uint256 public constant HIGH_RR = 4 * STANDARD_PRECISION;
    uint256 public constant TARGET_RR = 5 * STANDARD_PRECISION;
}
