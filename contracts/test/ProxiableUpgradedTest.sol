// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import '../abstracts/Proxiable.sol';

contract ProxiableUpgradedTest is Proxiable {
    function initialize() public override {
        super.initialize();
    }

    function feature() external pure returns (string memory) {
        return 'Upgraded Feature Output';
    }
}
