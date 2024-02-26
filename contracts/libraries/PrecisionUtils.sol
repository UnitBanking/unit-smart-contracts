// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import './ProtocolConstants.sol';

library PrecisionUtils {
    function toCollateralPrecision(
        uint256 standardPrecision,
        uint256 collateralTokenDecimals
    ) internal pure returns (uint256 collateralPrecision) {
        if (collateralTokenDecimals == ProtocolConstants.STANDARD_DECIMALS) {
            collateralPrecision = standardPrecision;
        } else if (collateralTokenDecimals < ProtocolConstants.STANDARD_DECIMALS) {
            collateralPrecision =
                standardPrecision /
                10 ** (ProtocolConstants.STANDARD_DECIMALS - collateralTokenDecimals);
        } else {
            collateralPrecision =
                standardPrecision *
                10 ** (collateralTokenDecimals - ProtocolConstants.STANDARD_DECIMALS);
        }
    }

    function toStandardPrecision(
        uint256 collateralPrecision,
        uint256 collateralTokenDecimals
    ) internal pure returns (uint256 standardPrecision) {
        if (collateralTokenDecimals == ProtocolConstants.STANDARD_DECIMALS) {
            standardPrecision = collateralPrecision;
        } else if (collateralTokenDecimals < ProtocolConstants.STANDARD_DECIMALS) {
            standardPrecision =
                collateralPrecision *
                10 ** (ProtocolConstants.STANDARD_DECIMALS - collateralTokenDecimals);
        } else {
            standardPrecision =
                collateralPrecision /
                10 ** (collateralTokenDecimals - ProtocolConstants.STANDARD_DECIMALS);
        }
    }
}
