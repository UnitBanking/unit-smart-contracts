// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import '../interfaces/IProxiable.sol';

abstract contract Proxiable is IProxiable {
    bool public initialized = false;

    function initialize() public virtual override {
        if (initialized) {
            revert ProxiableAlreadyInitialized();
        }
        initialized = true;
        emit InitializedBy(msg.sender);
    }
}
