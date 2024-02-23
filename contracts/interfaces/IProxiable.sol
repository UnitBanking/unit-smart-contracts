// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IProxiable {
    event InitializedBy(address proxy);

    error ProxiableAlreadyInitialized();

    function initialize() external;
}
