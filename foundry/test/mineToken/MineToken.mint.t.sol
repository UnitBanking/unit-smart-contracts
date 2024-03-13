// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Test } from 'forge-std/Test.sol';
import { MineTokenTestBase } from './MineTokenTestBase.t.sol';
import { Proxy } from '../../../contracts/Proxy.sol';
import { IMineToken } from '../../../contracts/interfaces/IMineToken.sol';

contract MineTokenMintTest is MineTokenTestBase {
    function test_mint_UserCanMint() public {
        uint256 balanceBefore = mineToken.balanceOf(address(this));
        uint256 totalSupply = mineToken.totalSupply();
        mineToken.mint(address(this), 100 * 1 ether);
        uint256 balanceAfter = mineToken.balanceOf(address(this));
        assertEq(totalSupply + 100 * 1 ether, mineToken.totalSupply());
        assertEq(balanceAfter, balanceBefore + 100 * 1 ether);
    }

    function test_mint_RevertsIfExceedsMaxSupply() public {
        uint256 maxSupply = mineToken.MAX_SUPPLY();
        vm.expectRevert(abi.encodeWithSelector(IMineToken.MineTokenExceedMaxSupply.selector));
        mineToken.mint(address(this), maxSupply + 1);
    }
}
