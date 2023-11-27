// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './abstracts/BaseToken.sol';
import './interfaces/IVote.sol';

contract MineToken is BaseToken, IVotes {
    error MineTokenExceedMaxSupply();

    address public defaultDelegatee;
    mapping(address => address) public delegates;

    struct Checkpoint {
        uint32 fromBlock;
        uint96 votes;
    }

    mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;
    mapping(address => uint32) public numCheckpoints;

    uint256 public constant MAX_SUPPLY = 1022700000 * 10 ** 18;
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256('EIP712Domain(string name,uint256 chainId,address verifyingContract)');
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256('Delegation(address delegatee,uint256 nonce,uint256 expiry)');

    mapping(address => uint256) public nonces;

    constructor() BaseToken() {}

    function initialize() public override {
        super.initialize();
    }

    function name() public pure override returns (string memory) {
        return 'Mine';
    }

    function symbol() public pure override returns (string memory) {
        return 'MINE';
    }

    function mint(address account, uint256 amount) public override {
        if(delegates[account] == address(0)) {
            _delegate(account, defaultDelegatee);
        }
        super.mint(account, amount);
        if (totalSupply > MAX_SUPPLY) {
            revert MineTokenExceedMaxSupply();
        }
    }

    function setDefaultDelegatee(address delegatee) external onlyOwner {
        uint32 nCheckpoints = numCheckpoints[defaultDelegatee];
        uint96 currentVotes = nCheckpoints > 0 ? checkpoints[defaultDelegatee][nCheckpoints - 1].votes : 0;
        _moveDelegates(defaultDelegatee, delegatee, currentVotes);
        _setDefaultDelegatee(delegatee);
    }

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        _moveDelegates(delegates[from], delegates[to], uint96(value));
    }

    function delegate(address delegatee) external {
        if(delegatee == defaultDelegatee) {
            revert DelegateToDefaultDelegatee();
        }
        return _delegate(msg.sender, delegatee);
    }

    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external {
        if (block.timestamp >= expiry) {
            revert DelegateExpired(expiry);
        }
        bytes32 domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name())), block.chainid, address(this))
        );
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked('\x19\x01', domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        if (signatory == address(0)) {
            revert InvalidDelegateSignature(signatory);
        }
        if (nonce != nonces[signatory]++){
            revert InvalidDelegateNonce(nonce);
        }
        return _delegate(signatory, delegatee);
    }

    function getCurrentVotes(address account) external view returns (uint96) {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    function getPriorVotes(address account, uint256 blockNumber) public view returns (uint96) {
        if (blockNumber > block.number) {
            revert BlockNumberTooHigh(blockNumber);
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
        address currentDelegate = delegates[delegator];
        uint256 delegatorBalance = balanceOf[delegator];
        delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, uint96(delegatorBalance));
    }

    function _setDefaultDelegatee(address _defaultDelegatee) internal {
        emit DefaultDelegateChanged(defaultDelegatee, _defaultDelegatee);
        defaultDelegatee = _defaultDelegatee;
    }

    function _moveDelegates(address from, address to, uint96 amount) internal {
        if (from != to && amount > 0) {
            if (from != address(0)) {
                uint32 fromRepNum = numCheckpoints[from];
                uint96 fromRepOld = fromRepNum > 0 ? checkpoints[from][fromRepNum - 1].votes : 0;
                uint96 fromRepNew = fromRepOld - amount;
                _writeCheckpoint(from, fromRepNum, fromRepOld, fromRepNew);
            }

            if (to != address(0)) {
                uint32 toRepNum = numCheckpoints[to];
                uint96 toRepOld = toRepNum > 0 ? checkpoints[to][toRepNum - 1].votes : 0;
                uint96 toRepNew = toRepOld + amount;
                _writeCheckpoint(to, toRepNum, toRepOld, toRepNew);
            }
        }
    }

    function _writeCheckpoint(address delegatee, uint32 nCheckpoints, uint96 oldVotes, uint96 newVotes) internal {
        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == block.number) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(uint32(block.number), newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }
}
