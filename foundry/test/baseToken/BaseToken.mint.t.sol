// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './BaseTokenTestCase.t.sol';
import { Mintable } from '../../../contracts/abstracts/Mintable.sol';

contract BaseTokenMintTest is BaseTokenBaseTest {
    event MinterSet(address indexed minter, bool canMint);

    function test_canMint() public {
        uint256 balanceBefore = baseToken.balanceOf(address(this));
        uint256 totalSupply = baseToken.totalSupply();
        baseToken.mint(address(this), 100 * 1 ether);
        uint256 balanceAfter = baseToken.balanceOf(address(this));
        assertEq(totalSupply + 100 * 1 ether, baseToken.totalSupply());
        assertEq(balanceAfter, balanceBefore + 100 * 1 ether);
    }

    function test_revertIfMinterIsNotAuthorized() public {
        address unauthorizedMinter = address(0x1);
        vm.expectRevert(
            abi.encodeWithSelector(Mintable.MintableUnauthorizedMinter.selector, address(unauthorizedMinter))
        );
        vm.prank(unauthorizedMinter);
        baseToken.mint(address(this), 100 * 1 ether);
    }

    function test_mintToOtherAddress() public {
        address receiver = address(0x1);
        uint256 balanceBefore = baseToken.balanceOf(receiver);
        baseToken.mint(receiver, 100 * 1 ether);
        uint256 balanceAfter = baseToken.balanceOf(receiver);
        assertEq(balanceAfter, balanceBefore + 100 * 1 ether);
    }

    function test_revertIfReceiverIsZeroAddress() public {
        address receiver = address(0x0);
        vm.expectRevert(abi.encodeWithSelector(Mintable.MintableInvalidReceiver.selector, receiver));
        baseToken.mint(receiver, 100 * 1 ether);
    }

    function test_setMinter() public {
        address minter = address(0x1);
        baseToken.setMinter(minter, true);
        assert(baseToken.isMinter(minter));
    }

    function test_revertIfSetMinterWithZeroAddress() public {
        address minter = address(0x0);
        vm.expectRevert(abi.encodeWithSelector(Mintable.MintableInvalidMinter.selector, minter));
        baseToken.setMinter(minter, true);
    }

    function test_revertIfSetMinterWithSameValue() public {
        address minter = address(0x1);
        baseToken.setMinter(minter, true);
        vm.expectRevert(abi.encodeWithSelector(Mintable.MintableSameValueAlreadySet.selector));
        baseToken.setMinter(minter, true);
    }

    function test_setMinterShouldEmitEvent() public {
        address minter = address(0x1);
        vm.expectEmit(true, true, true, true);
        emit MinterSet(minter, true);
        baseToken.setMinter(minter, true);
    }
}
