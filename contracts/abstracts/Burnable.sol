// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

abstract contract Burnable {
    event BurnerSet(address indexed burner, bool canBurn);

    error BurnableSameValueAlreadySet();
    error BurnableInvalidTokenOwner(address tokenOwner);
    error BurnableUnauthorizedBurner(address burner);

    mapping(address burner => bool canBurn) public isBurner;

    function _setBurner(address burner, bool canBurn) internal {
        if (isBurner[burner] == canBurn) {
            revert BurnableSameValueAlreadySet();
        }
        isBurner[burner] = canBurn;
        emit BurnerSet(burner, canBurn);
    }

    function burn(uint256 /* amount */) public virtual {
        _canBurn(msg.sender);
    }

    function burnFrom(address from, uint256 /* amount */) public virtual {
        if (from == address(0)) {
            revert BurnableInvalidTokenOwner(address(0));
        }
        _canBurn(msg.sender);
    }

    function _canBurn(address burner) private view {
        // everyone can burn when address(0) is burner
        if (!isBurner[address(0)] && !isBurner[burner]) {
            revert BurnableUnauthorizedBurner(burner);
        }
    }
}
