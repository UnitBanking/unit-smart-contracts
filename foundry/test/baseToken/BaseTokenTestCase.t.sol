// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { Test } from 'forge-std/Test.sol';
import { BaseTokenTest } from '../../../contracts/test/BaseTokenTest.sol';
import '../utils/SigUtils.sol';

abstract contract BaseTokenBaseTest is Test {
    BaseTokenTest public baseToken;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSpender(address spender);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    function setUp() public virtual {
        baseToken = new BaseTokenTest();
        baseToken.initialize();
        baseToken.setMinter(address(this), true);
        baseToken.setBurner(address(this), true);
        baseToken.mint(address(this), 100 * 1 ether);
    }
}
