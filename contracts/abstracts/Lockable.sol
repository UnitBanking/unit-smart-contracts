// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

abstract contract Lockable {
    error LockableContractLocked();

    uint256 private locked;

    modifier lock() {
        if (locked != 0) {
            revert LockableContractLocked();
        }
        locked = 1;
        _;
        locked = 0;
    }
}
