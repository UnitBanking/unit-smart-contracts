// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import './BaseTokenTestBase.t.sol';
import { IMintable } from '../../../contracts/abstracts/Mintable.sol';
import { IERC20 } from '../../../contracts/interfaces/IERC20.sol';

contract BaseTokenMintTest is BaseTokenTestBase {
    function test_mint_UserCanMint() public {
        uint256 balanceBefore = baseToken.balanceOf(address(this));
        uint256 totalSupply = baseToken.totalSupply();
        baseToken.mint(address(this), 100 * 1 ether);
        uint256 balanceAfter = baseToken.balanceOf(address(this));
        assertEq(totalSupply + 100 * 1 ether, baseToken.totalSupply());
        assertEq(balanceAfter, balanceBefore + 100 * 1 ether);
    }

    function test_mint_RevertsIfMinterIsNotAuthorized() public {
        address unauthorizedMinter = address(0x1);
        vm.expectRevert(
            abi.encodeWithSelector(IMintable.MintableUnauthorizedMinter.selector, address(unauthorizedMinter))
        );
        vm.prank(unauthorizedMinter);
        baseToken.mint(address(this), 100 * 1 ether);
    }

    function test_mint_CanMintToOtherAddress() public {
        address receiver = address(0x1);
        uint256 balanceBefore = baseToken.balanceOf(receiver);
        baseToken.mint(receiver, 100 * 1 ether);
        uint256 balanceAfter = baseToken.balanceOf(receiver);
        assertEq(balanceAfter, balanceBefore + 100 * 1 ether);
    }

    function test_mint_RevertsIfReceiverIsZeroAddress() public {
        address receiver = address(0x0);
        vm.expectRevert(abi.encodeWithSelector(IMintable.MintableInvalidReceiver.selector, receiver));
        baseToken.mint(receiver, 100 * 1 ether);
    }

    function test_mint_CanSetMinter() public {
        address minter = address(0x1);
        baseToken.setMinter(minter, true);
        assert(baseToken.isMinter(minter));
    }

    function test_mint_RevertsIfSetMinterWithZeroAddress() public {
        address minter = address(0x0);
        vm.expectRevert(abi.encodeWithSelector(IMintable.MintableInvalidMinter.selector, minter));
        baseToken.setMinter(minter, true);
    }

    function test_mint_RevertsIfSetMinterWithSameValue() public {
        address minter = address(0x1);
        baseToken.setMinter(minter, true);
        vm.expectRevert(abi.encodeWithSelector(IMintable.MintableSameValueAlreadySet.selector));
        baseToken.setMinter(minter, true);
    }

    function test_mint_SetMinterShouldEmitEvent() public {
        address minter = address(0x1);
        vm.expectEmit(true, true, true, true);
        emit IMintable.MinterSet(minter, true);
        baseToken.setMinter(minter, true);
    }
}
