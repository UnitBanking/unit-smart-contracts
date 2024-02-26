// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { Test } from 'forge-std/Test.sol';
import { MineTokenTestCase } from './MineTokenTestCase.t.sol';
import { Proxy } from '../../../contracts/Proxy.sol';
import { MineToken } from '../../../contracts/MineToken.sol';

contract MineTokenMintTest is MineTokenTestCase {
    function test_mint() public {
        uint256 balanceBefore = mineToken.balanceOf(address(this));
        uint256 totalSupply = mineToken.totalSupply();
        mineToken.mint(address(this), 100 * 1 ether);
        uint256 balanceAfter = mineToken.balanceOf(address(this));
        assertEq(totalSupply + 100 * 1 ether, mineToken.totalSupply());
        assertEq(balanceAfter, balanceBefore + 100 * 1 ether);
    }

    function test_revertIfExceedsMaxSupply() public {
        uint256 maxSupply = mineToken.MAX_SUPPLY();
        vm.expectRevert(abi.encodeWithSelector(MineToken.MineTokenExceedMaxSupply.selector));
        mineToken.mint(address(this), maxSupply + 1);
    }
}
