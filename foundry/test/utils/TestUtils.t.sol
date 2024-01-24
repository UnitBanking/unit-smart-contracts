// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

library TestUtils {
    uint256 internal constant START_TIMESTAMP = 1699023595;
    uint256 internal constant INITIAL_COLLATERAL_TOKEN_VALUE = 5 wei;
    uint256 internal constant INITIAL_UNIT_VALUE = 1 wei;

    uint256 internal constant RR_PRECISION = 1e18;
    uint256 internal constant HIGH_RR = 4 * RR_PRECISION;

    address internal constant COLLATERAL_BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function sendEth(address to, uint256 value) internal returns (bool success) {
        (success, ) = payable(to).call{ value: value }('');
    }
}
