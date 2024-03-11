// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { IBaseToken } from './IBaseToken.sol';
import { IVotes } from './IVotes.sol';

interface IMineToken is IBaseToken, IVotes {
    error MineTokenExceedMaxSupply();

    function setDefaultDelegatee(address delegatee) external;
}
