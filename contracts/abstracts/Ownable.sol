// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

abstract contract Ownable {
    event OwnerSet(address indexed owner);
    error OwnerDuplicatedOperation();
    error OwnableUnauthorizedAccount(address account);

    address public owner;

    modifier onlyOwner() {
        if (owner != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }

    function setOwner(address _owner) external virtual onlyOwner {
        _setOwner(_owner);
    }

    function _setOwner(address _owner) internal {
        if (owner == _owner) {
            revert OwnerDuplicatedOperation();
        }
        owner = _owner;
        emit OwnerSet(_owner);
    }
}
