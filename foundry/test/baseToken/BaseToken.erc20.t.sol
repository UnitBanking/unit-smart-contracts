// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './BaseTokenTestBase.t.sol';
import { IERC20 } from '../../../contracts/interfaces/IERC20.sol';

contract BaseTokenErc20Test is BaseTokenTestBase {
    function test_initialize_InitializesToken() public {
        assertEq(baseToken.name(), 'ERC20 Token');
        assertEq(baseToken.symbol(), 'ERC20');
        assertEq(baseToken.decimals(), 18);
    }

    function test_transfer_TransfersTokens() public {
        address to = address(0x1);
        uint256 amount = 10 * 1 ether;
        uint256 senderBalanceBefore = baseToken.balanceOf(address(this));
        uint256 receiverBalanceBefore = baseToken.balanceOf(to);

        baseToken.transfer(to, amount);

        uint256 senderBalanceAfter = baseToken.balanceOf(address(this));
        uint256 receiverBalanceAfter = baseToken.balanceOf(to);
        assertEq(senderBalanceAfter, senderBalanceBefore - amount);
        assertEq(receiverBalanceAfter, receiverBalanceBefore + amount);
    }

    function test_transfer_RevertsIfRecipientIsZeroAddress() public {
        address to = address(0);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20.ERC20InvalidReceiver.selector, 0x0000000000000000000000000000000000000000)
        );
        uint256 amount = 10 * 1 ether;
        baseToken.transfer(to, amount);
    }

    function test_transfer_RevertsIfSenderHasInsufficientBalance() public {
        uint256 balance = baseToken.balanceOf(address(this));
        uint256 amount = balance + 1;
        address to = address(0x1);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20.ERC20InsufficientBalance.selector, address(this), balance, amount)
        );
        baseToken.transfer(to, amount);
    }

    function test_approve_ApprovesSpender() public {
        address spender = address(0x1);
        uint256 amount = 10 * 1 ether;
        vm.expectEmit(true, true, true, true);
        emit Approval(address(this), spender, amount);
        baseToken.approve(spender, amount);
        assertEq(baseToken.allowance(address(this), spender), amount);
    }

    function test_approve_RevertsIfSpenderIsZeroAddress() public {
        address spender = address(0x0);
        uint256 amount = 10 * 1 ether;
        vm.expectRevert(abi.encodeWithSelector(IERC20.ERC20InvalidSpender.selector, spender));
        baseToken.approve(spender, amount);
    }

    function test_transferFrom_OtherAndAllowanceUpdated() public {
        address from = address(0x1);
        address to = address(0x2);
        address spender = address(this);
        uint256 amount = 10 * 1 ether;
        baseToken.mint(from, amount);
        vm.prank(from);
        baseToken.approve(spender, amount);
        uint256 fromBalanceBefore = baseToken.balanceOf(from);
        uint256 toBalanceBefore = baseToken.balanceOf(to);
        uint256 spenderAllowanceBefore = baseToken.allowance(from, spender);
        baseToken.transferFrom(from, to, amount);
        uint256 fromBalanceAfter = baseToken.balanceOf(from);
        uint256 toBalanceAfter = baseToken.balanceOf(to);
        uint256 spenderAllowanceAfter = baseToken.allowance(from, spender);
        assertEq(fromBalanceAfter, fromBalanceBefore - amount);
        assertEq(toBalanceAfter, toBalanceBefore + amount);
        assertEq(spenderAllowanceAfter, spenderAllowanceBefore - amount);
    }

    function test_approve_DoNotUpdateAllowanceWhenMax() public {
        address from = address(0x1);
        address to = address(0x2);
        address spender = address(this);
        uint256 amount = type(uint256).max;
        baseToken.mint(from, 10 * 1 ether);
        vm.prank(from);
        baseToken.approve(spender, amount);
        uint256 spenderAllowanceBefore = baseToken.allowance(from, spender);
        baseToken.transferFrom(from, to, 1 ether);
        uint256 spenderAllowanceAfter = baseToken.allowance(from, spender);
        assertEq(spenderAllowanceAfter, spenderAllowanceBefore);
    }

    function test_transferFrom_RevertsTransferFromIfAllowanceIsLow() public {
        address from = address(0x1);
        address to = address(0x2);
        address spender = address(this);
        uint256 amount = 10 * 1 ether;
        baseToken.mint(from, amount);
        vm.prank(from);
        baseToken.approve(spender, amount - 1);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20.ERC20InsufficientAllowance.selector, spender, amount - 1, amount)
        );
        baseToken.transferFrom(from, to, amount);
    }
}
