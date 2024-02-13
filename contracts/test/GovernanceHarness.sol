// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../Governance.sol';

contract GovernanceHarness is Governance {
    constructor(address _mineToken) Governance(_mineToken) {}
}
