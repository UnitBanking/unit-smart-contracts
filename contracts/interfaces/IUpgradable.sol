// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IUpgradable {
    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);

    error UpgradableInvalidImplementation(address implementation);
    error UpgradableInvalidAdmin(address admin);
    error UpgradableUnauthorized();
    error UpgradableDuplicatedOperation();
    error UpgradableNonPayable();
    error UpgradableFailedInnerCall();

    function implementation() external view returns (address);

    function upgradeTo(address newImplementation) external;

    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;

    function changeAdmin(address newAdmin) external;
}
