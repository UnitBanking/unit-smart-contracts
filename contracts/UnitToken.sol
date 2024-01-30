// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import './abstracts/BaseToken.sol';

/**
 * @dev IMPORTANT: This contract implements a proxy pattern. Do not modify inheritance list in this contract.
 * Adding, removing, changing or rearranging these base contracts can result in a storage collision after a contract upgrade.
 */
contract UnitToken is BaseToken {
    constructor() BaseToken() {}

    function initialize() public override {
        super.initialize();
    }

    function name() public pure override returns (string memory) {
        return 'Unit';
    }

    function symbol() public pure override returns (string memory) {
        return 'UNIT';
    }
}
