// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {IERC20} from "./IERC20.sol";
import {IERC20Permit} from "./IERC20Permit.sol";
import {IMintable} from "./IMintable.sol";
import {IBurnable} from "./IBurnable.sol";

interface IBaseToken is IERC20, IERC20Permit, IMintable, IBurnable {}