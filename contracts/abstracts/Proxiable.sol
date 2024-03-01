// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../interfaces/IProxiable.sol';

/**
 * @title Proxiable contract for initializing the contract
 * @notice You can use this contract to initialize the contract
 * @dev IMPORTANT: This contract is used as parent contract in contracts that implement a proxy pattern.
 * Adding, removing, changing or rearranging state variables in this contract can result in a storage collision
 * in child contracts in case of a contract upgrade.
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
