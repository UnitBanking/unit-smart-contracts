// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import '../UnitToken.sol';

contract UpgradedUnitToken is UnitToken {
    constructor() UnitToken() {}

    function newFeature() external pure returns (string memory) {
        return 'Upgraded Unit Token';
    }
}
