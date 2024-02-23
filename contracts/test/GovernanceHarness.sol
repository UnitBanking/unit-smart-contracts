// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../Governance.sol';

contract GovernanceHarness is Governance {
    constructor(address _mineToken) Governance(_mineToken) {}

    function exposed_castVote(uint256 proposalId, uint8 support) public returns (uint96) {
        return _castVote(msg.sender, proposalId, support);
    }

    function exposed_getChainId() public view returns (uint256 chainId) {
        chainId = _getChainId();
    }
}
