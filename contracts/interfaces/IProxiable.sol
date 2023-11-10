// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IProxiable {
    event DelegatedBy(address proxy);
    error ProxiableAlreadyDelegated();

    function initialize() external;
}
