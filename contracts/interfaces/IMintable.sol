// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IMintable {
    event MinterSet(address indexed minter, bool canMint);

    error MintableInvalidMinter(address minter);
    error MintableInvalidReceiver(address receiver);
    error MintableSameValueAlreadySet();
    error MintableUnauthorizedMinter(address minter);

    function isMinter(address minter) external returns (bool canMint);

    function mint(address receiver, uint256 amount) external;
}