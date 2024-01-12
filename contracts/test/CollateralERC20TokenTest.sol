// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import '../abstracts/ERC20.sol';

contract CollateralERC20TokenTest is ERC20 {
    function name() public view virtual override returns (string memory) {
        return 'Collateral ERC20 Token';
    }

    function symbol() public view virtual override returns (string memory) {
        return 'Collateral ERC20';
    }

    function mint(uint256 amount) external {
        _update(address(0), msg.sender, amount);
    }

    function burn(uint256 amount) external {
        _update(msg.sender, address(0), amount);
    }
}
