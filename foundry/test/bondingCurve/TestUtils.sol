// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

library TestUtils {
    function transferEth(address to, uint256 amount) internal returns (bool success) {
        (success, ) = to.call{ value: amount }('');
    }
}
