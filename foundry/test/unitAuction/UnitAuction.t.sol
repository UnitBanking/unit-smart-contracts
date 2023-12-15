// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { Test } from 'forge-std/Test.sol';
import { Proxy } from '../../../contracts/Proxy.sol';
import { UnitAuction } from '../../../contracts/auctions/UnitAuction.sol';

contract UnitAuctionTest is Test {
    uint256 internal constant START_TIMESTAMP = 1699023595;

    Proxy public proxy;
    UnitAuction public unitAuctionImplementation;
    UnitAuction public unitAuction;

    address public wallet = vm.addr(1);

    function setUp() public {
        // // set up wallet balance
        // vm.deal(wallet, 10 ether);

        // // set up block timestamp
        // vm.warp(START_TIMESTAMP);

        // proxy = new Proxy(address(this));
        // unitAuctionImplementation = new UnitAuction();
    }
}