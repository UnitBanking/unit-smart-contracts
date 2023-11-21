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

    function mint(uint256 amount) external virtual {
        _mint(msg.sender, amount);
    }

    function burn(uint256 amount) external virtual {
        _burn(msg.sender, amount);
    }

    function _mint(address account, uint256 amount) internal override {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        if (!isMintable[msg.sender]) {
            revert MintableUnauthorizedAccount(msg.sender);
        }
        _update(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal override {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        // everyone can burn when address(0) is burnable
        if (!isBurnable[address(0)] && !isBurnable[msg.sender]) {
            revert BurnableUnauthorizedAccount(msg.sender);
        }
        _update(account, address(0), amount);
    }
}
