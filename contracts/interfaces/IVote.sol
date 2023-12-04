// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IVotes {
    error VotesInvalidDelegateSignature(address signature);
    error VotesInvalidDelegateNonce(uint256 nonce);
    error VotesDelegationSignatureExpired(uint256 expiry);
    error VotesBlockNumberTooHigh(uint256 blockNumber);
    error VotesValueTooLarge(uint256 value);

    event DelegateSet(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesSet(address indexed delegate, uint256 previousBalance, uint256 newBalance);
    event DefaultDelegateeSet(address indexed oldDefaultDelegate, address indexed newDefaultDelegate);

    function getCurrentVotes(address account) external view returns (uint96);

    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);

    function delegatees(address account) external view returns (address);

    function delegate(address delegatee) external;

    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;
}
