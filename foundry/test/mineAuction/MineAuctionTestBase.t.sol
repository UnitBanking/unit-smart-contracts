// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { Test } from 'forge-std/Test.sol';
import '../../../contracts/MineAuction.sol';
import '../../../contracts/Proxy.sol';
import '../../../contracts/test/BaseTokenTest.sol';

contract MineAuctionTestBase is Test {
    MineAuction public mineAuction;
    MineToken public mineToken;
    BondingCurve public bondingCurve;
    BaseTokenTest public baseToken;

    address public other = address(0x02);
    address public another = address(0x03);

    function setUp() public {
        bondingCurve = BondingCurve(address(0x1));

        baseToken = new BaseTokenTest();
        baseToken.initialize();
        baseToken.setMinter(address(this), true);
        baseToken.setBurner(address(this), true);
        baseToken.mint(address(this), 100 * 1 ether);

        mineToken = new MineToken();
        mineToken.initialize();
        mineToken.setMinter(address(this), true);
        mineToken.setBurner(address(this), true);

        mineAuction = new MineAuction(bondingCurve, mineToken, baseToken, uint64(block.timestamp));
        Proxy proxy = new Proxy(address(this));
        proxy.upgradeToAndCall(address(mineAuction), abi.encodeWithSignature('initialize()'));
        mineAuction = MineAuction(address(proxy));

        mineToken.setMinter(address(mineAuction), true);

        baseToken.mint(address(this), 100000 * 1 ether);
        baseToken.mint(other, 100000 * 1 ether);
        baseToken.mint(another, 100000 * 1 ether);
        baseToken.approve(address(mineAuction), type(uint256).max);
        vm.prank(other);
        baseToken.approve(address(mineAuction), type(uint256).max);
        vm.prank(another);
        baseToken.approve(address(mineAuction), type(uint256).max);
    }
}
