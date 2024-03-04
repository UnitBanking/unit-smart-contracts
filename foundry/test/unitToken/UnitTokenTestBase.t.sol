// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { Test } from 'forge-std/Test.sol';
import { UnitToken } from '../../../contracts/UnitToken.sol';
import { Proxy } from '../../../contracts/Proxy.sol';

contract UnitTokenTestBase is Test {
    UnitToken public unitToken;
    Proxy public proxy;

    function setUp() public virtual {
        unitToken = new UnitToken();
        proxy = new Proxy(address(this));
        proxy.upgradeToAndCall(address(unitToken), abi.encodeWithSignature('initialize()'));
        unitToken = UnitToken(address(proxy));
        unitToken.setMinter(address(this), true);
        unitToken.setBurner(address(this), true);
        unitToken.mint(address(this), 100 * 1 ether);
    }

    function test_initialize() public {
        assertEq(unitToken.owner(), address(this));
    }
}
