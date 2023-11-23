// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './abstracts/BaseToken.sol';

contract UnitToken is BaseToken {
    constructor() BaseToken() {}

    function initialize() public override {
        super.initialize();
    }

    function name() public pure override returns (string memory) {
        return 'Unit Token';
    }

    function symbol() public pure override returns (string memory) {
        return 'UNIT';
    }
}
