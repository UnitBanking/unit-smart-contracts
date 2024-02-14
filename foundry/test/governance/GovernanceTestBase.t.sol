// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Test } from 'forge-std/Test.sol';
import { GovernanceHarness } from '../../../contracts/test/GovernanceHarness.sol';
import { IGovernance } from '../../../contracts/interfaces/IGovernance.sol';
import { MineToken } from '../../../contracts/MineToken.sol';
import { Proxy } from '../../../contracts/Proxy.sol';

abstract contract GovernanceTestBase is Test {
    uint256 internal constant START_TIMESTAMP = 1699023595;
    uint256 public constant INITIAL_VOTING_PERIOD = 5760;
    uint256 public constant INITIAL_VOTING_DELAY = 2;
    uint256 public constant INITIAL_PROPOSAL_THRESHOLD = 1000e18;

    MineToken public mineToken;

    Proxy public governanceProxyType;
    GovernanceHarness public governanceImplementation;
    GovernanceHarness public governanceProxy;

    address public wallet = vm.addr(1);

    function setUp() public {
        // set up wallet balance
        vm.deal(wallet, 10 ether);

        // set up block timestamp
        vm.warp(START_TIMESTAMP);

        // set up Mine token contract
        mineToken = new MineToken(); // TODO: use Proxy
        mineToken.initialize();
        mineToken.setMinter(wallet, true);

        // set up Governance contract
        governanceImplementation = new GovernanceHarness(address(mineToken));
        governanceProxyType = new Proxy(address(this));

        governanceProxyType.upgradeToAndCall(
            address(governanceImplementation),
            abi.encodeWithSelector(
                IGovernance.initialize.selector,
                5760, // blocks
                2, // blocks
                1000e18,
                3 days // seconds
            )
        );

        governanceProxy = GovernanceHarness(payable(governanceProxyType));
    }

    function _createUserAndMintMineToken(uint256 mineTokenAmount) internal returns (address user) {
        user = vm.addr(2);

        vm.warp(START_TIMESTAMP + 10 days);

        vm.prank(wallet);
        mineToken.mint(user, mineTokenAmount);
    }

    function _propose(address proposer) internal returns (uint256 proposalId) {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = 'proposal #1';

        vm.prank(proposer);
        governanceProxy.propose(targets, values, signatures, calldatas, description);

        proposalId = governanceProxy.proposalCount();
    }
}
