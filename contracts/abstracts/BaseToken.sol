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
        _setMintable(msg.sender, true);
        _setBurnable(msg.sender, true);
        super.initialize();
    }

    function setMintable(address minter, bool mintable) external onlyOwner {
        _setMintable(minter, mintable);
    }

    function setBurnable(address burner, bool burnable) external onlyOwner {
        _setBurnable(burner, burnable);
    }

    function mint(address account, uint256 amount) external virtual override {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, amount);
    }

    function burn(address account, uint256 amount) external virtual override {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), amount);
    }
}
