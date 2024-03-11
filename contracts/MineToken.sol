// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import './abstracts/BaseToken.sol';
import './interfaces/IMineToken.sol';

/**
 * @dev IMPORTANT: This contract implements a proxy pattern. Do not modify inheritance list in this contract.
 * Adding, removing, changing or rearranging these base contracts can result in a storage collision after a contract upgrade.
 */
contract MineToken is BaseToken, IMineToken {
    struct Checkpoint {
        uint32 fromBlock;
        uint96 votes;
    }

    uint256 public constant MAX_SUPPLY = 1022700000 * 10 ** 18;
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256('Delegation(address delegatee,uint256 nonce,uint256 expiry)');

    /**
     * IMPORTANT:
     * !STORAGE COLLISION WARNING!
     * Adding, removing or rearranging undermentioned state variables can result in a storage collision after a contract
     * upgrade. Any new state variables must be added beneath these to prevent storage conflicts.
     */

    address public defaultDelegatee;
    mapping(address delegator => address delegatee) public delegatees;

    mapping(address delegatee => mapping(uint32 index => Checkpoint checkpoint)) public checkpoints;
    mapping(address delegatee => uint32 count) public numCheckpoints;

    /**
     * IMPORTANT:
     * !STORAGE COLLISION WARNING!
     * Adding, removing or rearranging above state variables can result in a storage collision after a contract upgrade.
     * Any new state variables must be added beneath these to prevent storage conflicts.
     */

    constructor() BaseToken() {}

    function initialize() public override {
        super.initialize();
    }

    function name() public pure override(ERC20, IERC20) returns (string memory) {
        return 'Mine';
    }

    function symbol() public pure override(ERC20, IERC20) returns (string memory) {
        return 'MINE';
    }

    function mint(address receiver, uint256 amount) public override(BaseToken, IMintable) {
        if (delegatees[receiver] == address(0)) {
            _delegate(receiver, defaultDelegatee);
        }
        super.mint(receiver, amount);
        if (totalSupply > MAX_SUPPLY) {
            revert MineTokenExceedMaxSupply();
        }
    }

    function setDefaultDelegatee(address delegatee) external onlyOwner {
        uint32 nCheckpoints = numCheckpoints[defaultDelegatee];
        uint256 currentVotes = nCheckpoints > 0 ? checkpoints[defaultDelegatee][nCheckpoints - 1].votes : 0;
        _updateVotes(defaultDelegatee, delegatee, currentVotes);
        emit DefaultDelegateeSet(defaultDelegatee, delegatee);
        defaultDelegatee = delegatee;
    }

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        if (delegatees[to] == address(0) && to != address(0)) {
            delegatees[to] = defaultDelegatee;
            emit DelegateSet(to, address(0), defaultDelegatee);
        }
        _updateVotes(delegatees[from], delegatees[to], value);
    }

    function delegate(address delegatee) external override {
        return _delegate(msg.sender, delegatee);
    }

    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        if (block.timestamp > expiry) {
            revert VotesDelegationSignatureExpired(expiry);
        }
        bytes32 domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name())), block.chainid, address(this))
        );
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        if (signatory == address(0)) {
            revert VotesInvalidDelegateSignature(signatory);
        }
        if (nonce != nonces[signatory]++) {
            revert VotesInvalidDelegateNonce(nonce);
        }
        return _delegate(signatory, delegatee);
    }

    function getCurrentVotes(address account) external view override returns (uint96) {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    function getPriorVotes(address account, uint256 blockNumber) public view override returns (uint96) {
        if (blockNumber >= block.number) {
            revert VotesBlockNumberTooHigh(blockNumber);
        }

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        // bisect
        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee) internal {
        address oldDelegatee = delegatees[delegator];
        uint256 delegatorBalance = balanceOf[delegator];
        delegatees[delegator] = delegatee;

        emit DelegateSet(delegator, oldDelegatee, delegatee);

        _updateVotes(oldDelegatee, delegatee, delegatorBalance);
    }

    function _updateVotes(address from, address to, uint256 amount) internal {
        if (from != to && amount > 0) {
            if (from != address(0)) {
                uint32 nCheckpoints = numCheckpoints[from];
                uint256 oldVotes = nCheckpoints > 0 ? checkpoints[from][nCheckpoints - 1].votes : 0;
                uint256 newVotes = oldVotes - amount;
                _writeCheckpoint(from, nCheckpoints, oldVotes, newVotes);
            }

            if (to != address(0)) {
                uint32 nCheckpoints = numCheckpoints[to];
                uint256 oldVotes = nCheckpoints > 0 ? checkpoints[to][nCheckpoints - 1].votes : 0;
                uint256 newVotes = oldVotes + amount;
                _writeCheckpoint(to, nCheckpoints, oldVotes, newVotes);
            }
        }
    }

    function _writeCheckpoint(address delegatee, uint32 nCheckpoints, uint256 oldVotes, uint256 newVotes) internal {
        // Check is not needed because total supply ensures we can always downcast
        // if(newVotes > type(uint96).max) {
        //    revert VotesValueTooLarge(newVotes);
        // }
        uint96 newVotes96 = uint96(newVotes);
        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == block.number) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes96;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(uint32(block.number), newVotes96);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesSet(delegatee, oldVotes, newVotes);
    }
}
