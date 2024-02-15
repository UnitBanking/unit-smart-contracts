// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Test } from 'forge-std/Test.sol';
import { GovernanceHarness } from '../../../contracts/test/GovernanceHarness.sol';
import { IGovernance } from '../../../contracts/interfaces/IGovernance.sol';
import { MineToken } from '../../../contracts/MineToken.sol';
import { Proxy } from '../../../contracts/Proxy.sol';
import { Timelock } from '../../../contracts/Timelock.sol';

abstract contract GovernanceTestBase is Test {
    uint256 internal constant START_TIMESTAMP = 1699023595;
    uint256 public constant INITIAL_VOTING_PERIOD = 5760;
    uint256 public constant INITIAL_VOTING_DELAY = 2;
    uint256 public constant INITIAL_PROPOSAL_THRESHOLD = 1000e18;

    MineToken public mineToken;
    Timelock public timelock;

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

        // set up Timelock contract
        timelock = new Timelock(3 days);
        mineToken.setMinter(address(timelock), true);
        vm.prank(wallet);
        mineToken.mint(address(timelock), 10e18);

        // set up Governance contract
        governanceImplementation = new GovernanceHarness(address(mineToken));
        governanceProxyType = new Proxy(address(this));

        governanceProxyType.upgradeToAndCall(
            address(governanceImplementation),
            abi.encodeWithSelector(
                IGovernance.initialize.selector,
                address(timelock),
                5760, // blocks
                2, // blocks
                1000e18
            )
        );

        governanceProxy = GovernanceHarness(payable(governanceProxyType));
        governanceProxy.setWhitelistAccountExpiration(wallet, block.timestamp + 10_000);

        // set Timelock owner
        timelock.setOwner(address(governanceProxy));
    }

    function _createUserAndMintMineToken(uint256 mineTokenAmount) internal returns (address user) {
        user = vm.addr(2);

        vm.warp(START_TIMESTAMP + 10 days);

        vm.prank(wallet);
        mineToken.mint(user, mineTokenAmount);
    }

    function _propose(address proposer) internal returns (uint256 proposalId) {
        address[] memory targets = new address[](1);
        targets[0] = address(mineToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        string[] memory signatures = new string[](1);
        signatures[0] = 'transfer(address,uint256)';
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encode(proposer, 1e18);
        string memory description = 'proposal #1';

        vm.prank(proposer);
        governanceProxy.propose(targets, values, signatures, calldatas, description);

        proposalId = governanceProxy.proposalCount();
    }

    function _proposeWithDuplicatedTxs(address proposer) internal returns (uint256 proposalId) {
        // Proposal includes transfering 1 MINE token to the proposer's account
        address[] memory targets = new address[](2);
        targets[0] = address(mineToken);
        targets[1] = address(mineToken);
        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;
        string[] memory signatures = new string[](2);
        signatures[0] = 'transfer(address,uint256)';
        signatures[1] = 'transfer(address,uint256)';
        bytes[] memory calldatas = new bytes[](2);
        calldatas[0] = abi.encode(proposer, 1e18);
        calldatas[1] = abi.encode(proposer, 1e18);
        string memory description = 'proposal #1';

        vm.prank(proposer);
        governanceProxy.propose(targets, values, signatures, calldatas, description);

        proposalId = governanceProxy.proposalCount();
    }

    function _voteAndRollToEndBlock(uint256 proposalId, address voter) internal {
        uint256 startBlock = block.number + governanceProxy.votingDelay();
        uint256 endBlock = startBlock + governanceProxy.votingPeriod();
        vm.roll(startBlock + 1);

        vm.prank(voter);
        governanceProxy.castVote(proposalId, 1);

        vm.roll(endBlock + 1);
    }
}
