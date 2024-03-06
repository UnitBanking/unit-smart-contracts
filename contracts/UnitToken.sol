// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import './abstracts/BaseToken.sol';
import './interfaces/IUnitToken.sol';

/**
 * @dev IMPORTANT: This contract implements a proxy pattern. Do not modify inheritance list in this contract.
 * Adding, removing, changing or rearranging these base contracts can result in a storage collision after a contract upgrade.
 */
contract UnitToken is BaseToken, IUnitToken {
    constructor() BaseToken() {}

    function initialize() public override {
        super.initialize();
    }

    function name() public pure override(ERC20, IERC20) returns (string memory) {
        return 'Unit';
    }

    function symbol() public pure override(ERC20, IERC20) returns (string memory) {
        return 'UNIT';
    }
}
