// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../interfaces/IProxiable.sol';

/**
 * @title Proxiable contract for initializing the contract
 * @notice You can use this contract to initialize the contract
 * @dev The initialize function should be called only once
 */
abstract contract Proxiable is IProxiable {
    bool public initialized;

    /**
     * @notice Emitted when the contract is initialized
     * @dev This event is emitted when the contract is initialized, and it should only initialize once
     */
    function initialize() public virtual override {
        if (initialized) {
            revert ProxiableAlreadyInitialized();
        }
        initialized = true;
        emit InitializedBy(msg.sender);
    }
}
