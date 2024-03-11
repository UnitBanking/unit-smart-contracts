// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

/**
 * @dev IMPORTANT: This contract is used as parent contract in contracts that implement a proxy pattern.
 * Adding, removing, changing or rearranging state variables in this contract can result in a storage collision
 * in child contracts in case of a contract upgrade.
 */
abstract contract Ownable {
    event OwnerSet(address indexed owner);

    error OwnableInvalidOwner(address owner);
    error OwnableSameValueAlreadySet();
    error OwnableUnauthorizedOwner(address owner);

    address public owner;

    modifier onlyOwner() {
        if (owner != msg.sender) {
            revert OwnableUnauthorizedOwner(msg.sender);
        }
        _;
    }

    function setOwner(address _owner) external virtual onlyOwner {
        _setOwner(_owner);
    }

    function _setOwner(address _owner) internal {
        if (_owner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        if (_owner == owner) {
            revert OwnableSameValueAlreadySet();
        }
        owner = _owner;
        emit OwnerSet(_owner);
    }
}
