// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './abstracts/BaseToken.sol';

contract UnitToken is BaseToken {
    constructor() BaseToken() {}

    function initialize() public override {
        name = 'Unit Token';
        symbol = 'UNIT';
        decimals = 18;
        super.initialize();
    }
}
