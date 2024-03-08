// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Test } from 'forge-std/Test.sol';
import '../../../contracts/libraries/PrecisionUtils.sol';
import { TestUtils } from '../utils/TestUtils.t.sol';

contract PrecisionUtilsTest is Test {
    using PrecisionUtils for uint256;

    // ================ CONVERT TO STANDARD PRECISION ================
    function test_lowerToStandardPrecision() public {
        for (uint i = 0; i < TestUtils.STANDARD_DECIMALS; ++i) {
            // Act
            uint256 testValue = uint256(10 ** i).toStandardPrecision(i);
            uint256 expectedValue = TestUtils.STANDARD_PRECISION;

            // Assert
            assertEq(testValue, expectedValue);
        }
    }

    function test_standardToStandardPrecision() public {
        // Act
        uint256 testValue = uint256(TestUtils.STANDARD_PRECISION).toStandardPrecision(TestUtils.STANDARD_DECIMALS);
        uint256 expectedValue = TestUtils.STANDARD_PRECISION;

        // Assert
        assertEq(testValue, expectedValue);
    }

    uint256 constant MAX_UINT256_DECIMALS = 77;

    function test_higherToStandardPrecision() public {
        for (uint i = TestUtils.STANDARD_DECIMALS + 1; i <= MAX_UINT256_DECIMALS; ++i) {
            // Act
            uint256 testValue = uint256(10 ** i).toStandardPrecision(i);
            uint256 expectedValue = TestUtils.STANDARD_PRECISION;

            // Assert
            assertEq(testValue, expectedValue);
        }
    }

    function test_lowerPrecisionZeroToStandardPrecision() public {
        for (uint i = 0; i < TestUtils.STANDARD_DECIMALS; ++i) {
            // Act
            uint256 testValue = uint256(0).toStandardPrecision(i);
            uint256 expectedValue = 0;

            // Assert
            assertEq(testValue, expectedValue);
        }
    }

    function test_standardPrecisionZeroToStandardPrecision() public {
        // Act
        uint256 testValue = uint256(0).toStandardPrecision(TestUtils.STANDARD_DECIMALS);
        uint256 expectedValue = 0;

        // Assert
        assertEq(testValue, expectedValue);
    }

    function test_higherPrecisionZeroToStandardPrecision() public {
        for (uint i = TestUtils.STANDARD_DECIMALS + 1; i <= MAX_UINT256_DECIMALS; ++i) {
            // Act
            uint256 testValue = uint256(0).toStandardPrecision(i);
            uint256 expectedValue = 0;

            // Assert
            assertEq(testValue, expectedValue);
        }
    }

    function test_6PrecisionToStandardPrecision() public {
        // Arrange
        uint256 testDecimals = 6;

        // Act
        uint256 testValue0 = uint256(112233).toStandardPrecision(testDecimals);
        uint256 expectedValue0 = 112233 * 1e12;
        uint256 testValue1 = uint256(112233000000).toStandardPrecision(testDecimals);
        uint256 expectedValue1 = 112233 * 1e18;
        uint256 testValue2 = uint256(112233445566).toStandardPrecision(testDecimals);
        uint256 expectedValue2 = 112233445566 * 1e12;
        uint256 testValue3 = uint256(11223344556677).toStandardPrecision(testDecimals);
        uint256 expectedValue3 = 11223344556677 * 1e12;

        // Assert
        assertEq(testValue0, expectedValue0);
        assertEq(testValue1, expectedValue1);
        assertEq(testValue2, expectedValue2);
        assertEq(testValue3, expectedValue3);
    }

    // function test_24PrecisionToStandardPrecision() public {
    // }

    // ================ CONVERT FROM STANDARD PRECISION ================

    // function test_lowerFromStandardPrecision() public {
    // }

    // function test_standardFromStandardPrecision() public {
    // }

    // function test_higherFromStandardPrecision() public {
    // }

    // function test_lowerPrecisionZeroFromStandardPrecision() public {
    // }

    // function test_standardPrecisionZeroFromStandardPrecision() public {
    // }

    // function test_higherPrecisionZeroFromStandardPrecision() public {
    // }

    function test_6PrecisionFromStandardPrecision() public {
        // Arrange
        uint256 testDecimals = 6;

        // Act
        uint256 testValue0 = uint256(112233445566).fromStandardPrecision(testDecimals);
        uint256 expectedValue0 = 0;
        uint256 testValue1 = uint256(112233445566 * 1e12).fromStandardPrecision(testDecimals);
        uint256 expectedValue1 = 112233445566;
        uint256 testValue2 = uint256(112233445566 * 10 ** TestUtils.STANDARD_DECIMALS).fromStandardPrecision(
            testDecimals
        );
        uint256 expectedValue2 = 112233445566000000;

        // Assert
        assertEq(testValue0, expectedValue0);
        assertEq(testValue1, expectedValue1);
        assertEq(testValue2, expectedValue2);
    }

    // function test_24PrecisionFromStandardPrecision() public {
    // }

    // ================ INVERSION ================
    function test_6PrecisionInversion() public {
        // Arrange
        uint256 testDecimals = 6;

        // Act
        uint256 expectedValue0 = 0;
        uint256 testValue0 = uint256(expectedValue0).toStandardPrecision(testDecimals).fromStandardPrecision(
            testDecimals
        );
        uint256 expectedValue1 = 112233000000;
        uint256 testValue1 = uint256(expectedValue1).toStandardPrecision(testDecimals).fromStandardPrecision(
            testDecimals
        );
        uint256 expectedValue2 = 112233445566;
        uint256 testValue2 = uint256(expectedValue2).toStandardPrecision(testDecimals).fromStandardPrecision(
            testDecimals
        );
        uint256 expectedValue3 = 11223344556677;
        uint256 testValue3 = uint256(expectedValue3).toStandardPrecision(testDecimals).fromStandardPrecision(
            testDecimals
        );
        uint256 expectedValue4 = type(uint256).max / 10 ** (TestUtils.STANDARD_DECIMALS - testDecimals);
        uint256 testValue4 = uint256(expectedValue4).toStandardPrecision(testDecimals).fromStandardPrecision(
            testDecimals
        );

        // Assert
        assertEq(testValue0, expectedValue0);
        assertEq(testValue1, expectedValue1);
        assertEq(testValue2, expectedValue2);
        assertEq(testValue3, expectedValue3);
        assertEq(testValue4, expectedValue4);
    }

    function test_24PrecisionInversion() public {
        // Arrange
        uint256 testDecimals = 24;

        // Avoiding stack too deep errors
        {
            // Act
            uint256 testValue0 = uint256(0).toStandardPrecision(testDecimals).fromStandardPrecision(testDecimals);
            uint256 expectedValue0 = 0;
            uint256 testValue1 = uint256(112233).toStandardPrecision(testDecimals).fromStandardPrecision(testDecimals);
            uint256 expectedValue1 = 0;
            uint256 testValue2 = uint256(112233000000).toStandardPrecision(testDecimals).fromStandardPrecision(
                testDecimals
            );
            uint256 expectedValue2 = 112233000000;
            uint256 testValue3 = uint256(112233445566).toStandardPrecision(testDecimals).fromStandardPrecision(
                testDecimals
            );
            uint256 expectedValue3 = 112233000000;
            uint256 testValue4 = uint256(11223344556677).toStandardPrecision(testDecimals).fromStandardPrecision(
                testDecimals
            );
            uint256 expectedValue4 = 11223344000000;
            uint256 testValue5 = uint256(112233445566778899001122)
                .toStandardPrecision(testDecimals)
                .fromStandardPrecision(testDecimals);
            uint256 expectedValue5 = 112233445566778899000000;

            // Assert
            assertEq(testValue0, expectedValue0);
            assertEq(testValue1, expectedValue1);
            assertEq(testValue2, expectedValue2);
            assertEq(testValue3, expectedValue3);
            assertEq(testValue4, expectedValue4);
            assertEq(testValue5, expectedValue5);
        }

        // Act
        uint256 testValue6 = uint256(1122334455667788990011223344)
            .toStandardPrecision(testDecimals)
            .fromStandardPrecision(testDecimals);
        uint256 expectedValue6 = 1122334455667788990011000000;
        uint256 testValue7 = uint256(type(uint256).max).toStandardPrecision(testDecimals).fromStandardPrecision(
            testDecimals
        );
        uint256 decimalsDiff = testDecimals - TestUtils.STANDARD_DECIMALS;
        uint256 expectedValue7 = (type(uint256).max / 10 ** (decimalsDiff)) * 10 ** decimalsDiff;

        // Assert
        assertEq(testValue6, expectedValue6);
        assertEq(testValue7, expectedValue7);
    }

    function test_standardPrecisionInversion() public {
        // Arrange
        uint256 testDecimals = TestUtils.STANDARD_DECIMALS;

        // Avoiding stack too deep errors
        {
            // Act
            uint256 expectedValue0 = 0;
            uint256 testValue0 = uint256(expectedValue0).toStandardPrecision(testDecimals).fromStandardPrecision(
                testDecimals
            );
            uint256 expectedValue1 = 1;
            uint256 testValue1 = uint256(expectedValue1).toStandardPrecision(testDecimals).fromStandardPrecision(
                testDecimals
            );
            uint256 expectedValue2 = 112233000000;
            uint256 testValue2 = uint256(expectedValue2).toStandardPrecision(testDecimals).fromStandardPrecision(
                testDecimals
            );
            uint256 expectedValue3 = 112233445566;
            uint256 testValue3 = uint256(expectedValue3).toStandardPrecision(testDecimals).fromStandardPrecision(
                testDecimals
            );
            uint256 expectedValue4 = 112233445566778899;
            uint256 testValue4 = uint256(expectedValue4).toStandardPrecision(testDecimals).fromStandardPrecision(
                testDecimals
            );
            uint256 expectedValue5 = 11223344556677889900;
            uint256 testValue5 = uint256(expectedValue5).toStandardPrecision(testDecimals).fromStandardPrecision(
                testDecimals
            );

            // Assert
            assertEq(testValue0, expectedValue0);
            assertEq(testValue1, expectedValue1);
            assertEq(testValue2, expectedValue2);
            assertEq(testValue3, expectedValue3);
            assertEq(testValue4, expectedValue4);
            assertEq(testValue5, expectedValue5);
        }

        // Act
        uint256 expectedValue6 = 1122334455667788990011;
        uint256 testValue6 = uint256(expectedValue6).toStandardPrecision(testDecimals).fromStandardPrecision(
            testDecimals
        );
        uint256 expectedValue7 = type(uint256).max;
        uint256 testValue7 = uint256(expectedValue7).toStandardPrecision(testDecimals).fromStandardPrecision(
            testDecimals
        );

        // Assert
        assertEq(testValue6, expectedValue6);
        assertEq(testValue7, expectedValue7);
    }
}
