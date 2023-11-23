// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IProxy {
    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);

    error ProxyInvalidImplementation(address implementation);
    error ProxyInvalidAdmin(address admin);
    error ProxyUnauthorized();
    error ProxyDuplicatedOperation();
    error ProxyNonPayable();
    error ProxyFailedInnerCall();

    function implementation() external view returns (address);

    function admin() external view returns (address);

    function upgradeTo(address newImplementation) external;

    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

    function changeAdmin(address newAdmin) external;
}
