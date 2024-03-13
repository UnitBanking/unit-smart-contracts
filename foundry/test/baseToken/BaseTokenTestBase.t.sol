// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Test } from 'forge-std/Test.sol';
import { BaseTokenTest } from '../../../contracts/test/BaseTokenTest.sol';
import '../utils/SigUtils.sol';

abstract contract BaseTokenTestBase is Test {
    BaseTokenTest public baseToken;

    function setUp() public virtual {
        baseToken = new BaseTokenTest();
        baseToken.initialize();
        baseToken.setMinter(address(this), true);
        baseToken.setBurner(address(this), true);
        baseToken.mint(address(this), 100 * 1 ether);
    }
}
