// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import '../abstracts/BaseToken.sol';

contract BaseTokenTest is BaseToken {
    constructor() BaseToken() {}

    function mintTo(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burnFrom(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
