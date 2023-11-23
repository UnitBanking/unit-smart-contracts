// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './ERC20.sol';
import './Mintable.sol';
import './Burnable.sol';
import './Ownable.sol';
import './Proxiable.sol';

abstract contract BaseToken is Ownable, ERC20, Mintable, Burnable, Proxiable {
    constructor() ERC20() {}

    function initialize() public virtual override {
        _setOwner(msg.sender);
        super.initialize();
    }

    function setMinter(address minter, bool canMint) external onlyOwner {
        _setMinter(minter, canMint);
    }

    function setBurner(address burner, bool canBurn) external onlyOwner {
        _setBurner(burner, canBurn);
    }

    function mint(address account, uint256 amount) public virtual override {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        super.mint(account, amount);
        _update(address(0), account, amount);
    }

    function burn(uint256 amount) public virtual override {
        super.burn(amount);
        _update(msg.sender, address(0), amount);
    }
}
