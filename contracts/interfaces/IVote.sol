// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IVotes {
    error InvalidDelegateSignature(address signature);
    error InvalidDelegateNonce(uint256 nonce);
    error DelegateExpired(uint256 expiry);
    error BlockNumberTooHigh(uint256 blockNumber);

    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);
    event DefaultDelegateChanged(address indexed oldDefaultDelegate, address indexed newDefaultDelegate);

    function getCurrentVotes(address account) external view returns (uint256);

    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256);

    function delegates(address account) external view returns (address);

    function delegate(address delegatee) external;

    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;
}
