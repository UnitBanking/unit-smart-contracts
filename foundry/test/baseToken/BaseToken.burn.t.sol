// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import './BaseTokenTestBase.t.sol';
import { IERC20 } from '../../../contracts/interfaces/IERC20.sol';
import { IBurnable } from '../../../contracts/abstracts/Burnable.sol';

contract BaseTokenBurnTest is BaseTokenTestBase {
    function test_burn_UserCanBurn() public {
        uint256 balanceBefore = baseToken.balanceOf(address(this));
        uint256 totalSupply = baseToken.totalSupply();
        baseToken.burn(100 * 1 ether);
        uint256 balanceAfter = baseToken.balanceOf(address(this));
        assertEq(totalSupply - 100 * 1 ether, baseToken.totalSupply());
        assertEq(balanceAfter, balanceBefore - 100 * 1 ether);
    }

    function test_burn_RevertsIfBurnerIsNotAuthorized() public {
        address unauthorizedBurner = address(0x1);
        vm.expectRevert(
            abi.encodeWithSelector(IBurnable.BurnableUnauthorizedBurner.selector, address(unauthorizedBurner))
        );
        vm.prank(unauthorizedBurner);
        baseToken.burn(100 * 1 ether);
    }

    function test_burn_CanBurnIfBurnerIsZeroAddress() public {
        address burner = address(0x0);
        baseToken.setBurner(burner, true);
        uint256 balanceBefore = baseToken.balanceOf(address(this));
        baseToken.burn(100 * 1 ether);
        uint256 balanceAfter = baseToken.balanceOf(address(this));
        assertEq(balanceAfter, balanceBefore - 100 * 1 ether);
    }

    function test_burn_BurnFromOtherAddress() public {
        address burner = address(0x1);
        uint256 amount = 100 * 1 ether;
        baseToken.mint(burner, amount);
        uint256 totalSupply = baseToken.totalSupply();
        uint256 balanceBefore = baseToken.balanceOf(burner);
        vm.prank(burner);
        baseToken.approve(address(this), amount);
        uint256 allowanceBefore = baseToken.allowance(burner, address(this));
        baseToken.burnFrom(burner, amount);
        uint256 allowanceAfter = baseToken.allowance(burner, address(this));
        assertEq(allowanceAfter, allowanceBefore - amount);
        uint256 balanceAfter = baseToken.balanceOf(burner);
        assertEq(balanceAfter, balanceBefore - amount);
        assertEq(totalSupply - amount, baseToken.totalSupply());
    }

    function test_burn_BurnFromZeroAmount() public {
        address burner = address(0x1);
        uint256 amount = 0;
        baseToken.mint(burner, amount);
        uint256 totalSupply = baseToken.totalSupply();
        uint256 balanceBefore = baseToken.balanceOf(burner);
        vm.prank(burner);
        baseToken.approve(address(this), amount);
        baseToken.burnFrom(burner, amount);
        uint256 balanceAfter = baseToken.balanceOf(burner);
        assertEq(balanceAfter, balanceBefore - amount);
        assertEq(totalSupply - amount, baseToken.totalSupply());
    }

    function test_burn_RevertsIfBurnFromNoAllowance() public {
        address burner = address(0x1);
        uint256 amount = 100 * 1 ether;
        baseToken.mint(burner, amount);
        uint256 allowance = baseToken.allowance(burner, address(this));
        vm.expectRevert(
            abi.encodeWithSelector(IERC20.ERC20InsufficientAllowance.selector, address(this), allowance, amount)
        );
        baseToken.burnFrom(burner, amount);
    }

    function test_burn_RevertsIfBurnFromZeroAddress() public {
        address burner = address(0x0);
        uint256 amount = 100 * 1 ether;
        vm.expectRevert(abi.encodeWithSelector(IBurnable.BurnableInvalidTokenOwner.selector, address(burner)));
        baseToken.burnFrom(burner, amount);
    }

    function test_burn_UserCanSetBurner() public {
        address burner = address(0x1);
        baseToken.setBurner(burner, true);
        assert(baseToken.isBurner(burner));
    }

    function test_burn_RevertsIfSetBurnerSameValue() public {
        address burner = address(0x1);
        baseToken.setBurner(burner, true);
        vm.expectRevert(abi.encodeWithSelector(IBurnable.BurnableSameValueAlreadySet.selector));
        baseToken.setBurner(burner, true);
    }

    function test_burn_SetBurnerShouldEmitEvent() public {
        address burner = address(0x1);
        vm.expectEmit(true, true, true, true);
        emit IBurnable.BurnerSet(burner, true);
        baseToken.setBurner(burner, true);
    }
}