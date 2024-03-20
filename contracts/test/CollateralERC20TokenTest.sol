// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../abstracts/ERC20.sol';

contract CollateralERC20TokenTest is ERC20 {
    uint8 private immutable _decimals;

    constructor(uint8 d) {
        _decimals = d;
    }

    function name() public view virtual override returns (string memory) {
        return 'Collateral ERC20 Token';
    }

    function symbol() public view virtual override returns (string memory) {
        return 'Collateral ERC20';
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(uint256 amount) external {
        _update(address(0), msg.sender, amount);
    }

    function burn(uint256 amount) external {
        _update(msg.sender, address(0), amount);
    }
}
