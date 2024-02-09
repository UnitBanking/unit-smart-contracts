// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import './interfaces/IProxy.sol';

contract Proxy is IProxy {
    constructor(address __admin) {
        _changeAdmin(__admin);
    }

    modifier onlyAdmin() {
        if (msg.sender != _admin()) {
            revert ProxyUnauthorizedAdmin();
        }
        _;
    }

    function implementation() external view returns (address) {
        return _implementation();
    }

    function admin() external view returns (address) {
        return _admin();
    }

    function upgradeTo(address __implementation) external onlyAdmin {
        _upgradeToAndCall(__implementation, new bytes(0));
    }

    function upgradeToAndCall(address __implementation, bytes memory data) external payable onlyAdmin {
        _upgradeToAndCall(__implementation, data);
    }

    function changeAdmin(address __admin) external onlyAdmin {
        _changeAdmin(__admin);
    }

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
     */
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Returns the current implementation address.
     */
    function _implementation() internal view returns (address __implementation) {
        assembly {
            __implementation := sload(IMPLEMENTATION_SLOT)
        }
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address __implementation) internal {
        if (__implementation.code.length == 0) {
            revert ProxyInvalidImplementation(__implementation);
        }
        if (__implementation == _implementation()) {
            revert ProxySameValueAlreadySet();
        }
        assembly {
            sstore(IMPLEMENTATION_SLOT, __implementation)
        }
    }

    /**
     * @dev Performs implementation upgrade with additional setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     */
    function _upgradeToAndCall(address __implementation, bytes memory data) internal {
        _setImplementation(__implementation);
        emit Upgraded(__implementation);

        if (data.length > 0) {
            (bool success, bytes memory returndata) = __implementation.delegatecall(data);
            if (!success) {
                if (returndata.length > 0) {
                    // The easiest way to bubble the revert reason is using memory via assembly
                    assembly {
                        let returndata_size := mload(returndata)
                        revert(add(32, returndata), returndata_size)
                    }
                } else {
                    revert ProxyFailedInnerCall();
                }
            }
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1.
     */
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using
     * the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function _admin() internal view returns (address __admin) {
        assembly {
            __admin := sload(ADMIN_SLOT)
        }
    }

    /**
     * @dev Changes the admin of the proxy. Stores a new address in the EIP1967 admin slot.
     */
    function _changeAdmin(address __admin) internal {
        if (__admin == address(0)) {
            revert ProxyInvalidAdmin(address(0));
        }
        if (__admin == _admin()) {
            revert ProxySameValueAlreadySet();
        }
        assembly {
            sstore(ADMIN_SLOT, __admin)
        }

        emit AdminChanged(_admin(), __admin);
    }

    /**
     * @dev Reverts if `msg.value` is not zero. It can be used to avoid `msg.value` stuck in the contract
     * if an upgrade doesn't perform an initialization call.
     */
    function _checkNonPayable() internal {
        if (msg.value > 0) {
            revert ProxyNonPayable();
        }
    }

    /**
     * @dev Delegates the current call to `_implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback(address __implementation) internal {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the _implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), __implementation, 0, calldatasize(), 0, 0)

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
        _fallback(_implementation());
    }

    receive() external payable {
        _fallback(_implementation());
    }
}
