// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './abstracts/Upgradable.sol';

contract Proxy is Upgradable {
    constructor(address admin) {
        _changeAdmin(admin);
    }

    modifier onlyAdmin() {
        if (msg.sender != getAdmin()) {
            revert UpgradableUnauthorized();
        }
        _;
    }

    function implementation() external view returns (address) {
        return _getImplementation();
    }

    function upgradeTo(address newImplementation) external onlyAdmin {
        _upgradeToAndCall(newImplementation, new bytes(0));
    }

    function upgradeToAndCall(address newImplementation, bytes memory data) external payable onlyAdmin {
        _upgradeToAndCall(newImplementation, data);
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        _changeAdmin(newAdmin);
    }

    /**
     * @dev Delegates the current call to `_implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback(address _implementation) internal {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the _implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    fallback() external payable {
        _fallback(_getImplementation());
    }

    receive() external payable {
        _fallback(_getImplementation());
    }
}
