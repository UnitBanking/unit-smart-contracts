// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import './ProtocolConstants.sol';

library PrecisionUtils {
    function convertPrecision(
        uint256 originalPrecisionValue,
        uint256 originalDecimals,
        uint256 targetDecimals
    ) internal pure returns (uint256 targetPrecisionValue) {
        if (targetDecimals == originalDecimals) {
            targetPrecisionValue = originalPrecisionValue;
        } else if (targetDecimals < originalDecimals) {
            targetPrecisionValue = originalPrecisionValue / 10 ** (originalDecimals - targetDecimals);
        } else {
            targetPrecisionValue = originalPrecisionValue * 10 ** (targetDecimals - originalDecimals);
        }
    }

    function toStandardPrecision(
        uint256 originalPrecisionValue,
        uint256 originalDecimals
    ) internal pure returns (uint256 standardPrecisionValue) {
        standardPrecisionValue = convertPrecision(
            originalPrecisionValue,
            originalDecimals,
            ProtocolConstants.STANDARD_DECIMALS
        );
    }

    function fromStandardPrecision(
        uint256 standardPrecisionValue,
        uint256 targetDecimals
    ) internal pure returns (uint256 targetPrecisionValue) {
        targetPrecisionValue = convertPrecision(
            standardPrecisionValue,
            ProtocolConstants.STANDARD_DECIMALS,
            targetDecimals
        );
    }
}
