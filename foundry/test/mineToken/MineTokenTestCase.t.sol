// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { Test } from 'forge-std/Test.sol';
import { MineToken } from '../../../contracts/MineToken.sol';
import { Proxy } from '../../../contracts/Proxy.sol';
import '../../../contracts/MineToken.sol';

contract MineTokenTestCase is Test {
    MineToken public mineToken;
    Proxy public proxy;

    function setUp() public virtual {
        mineToken = new MineToken();
        proxy = new Proxy(address(this));
        proxy.upgradeToAndCall(address(mineToken), abi.encodeWithSignature('initialize()'));
        mineToken = MineToken(address(proxy));
        mineToken.setMinter(address(this), true);
        mineToken.setBurner(address(this), true);
    }

    function test_initialize() public {
        assertEq(mineToken.owner(), address(this));
    }

    function test_info() public {
        assertEq(mineToken.name(), 'Mine');
        assertEq(mineToken.symbol(), 'MINE');
        assertEq(mineToken.decimals(), 18);
        assertEq(mineToken.MAX_SUPPLY(), 1022700000 * 1 ether);
    }
}
