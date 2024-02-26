// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './BaseTokenTestCase.t.sol';
import { Burnable } from '../../../contracts/abstracts/Burnable.sol';

contract BaseTokenBurnTest is BaseTokenBaseTest {
    event BurnerSet(address indexed burner, bool canBurn);

    function test_canBurn() public {
        uint256 balanceBefore = baseToken.balanceOf(address(this));
        uint256 totalSupply = baseToken.totalSupply();
        baseToken.burn(100 * 1 ether);
        uint256 balanceAfter = baseToken.balanceOf(address(this));
        assertEq(totalSupply - 100 * 1 ether, baseToken.totalSupply());
        assertEq(balanceAfter, balanceBefore - 100 * 1 ether);
    }

    function test_revertIfBurnerIsNotAuthorized() public {
        address unauthorizedBurner = address(0x1);
        vm.expectRevert(
            abi.encodeWithSelector(Burnable.BurnableUnauthorizedBurner.selector, address(unauthorizedBurner))
        );
        vm.prank(unauthorizedBurner);
        baseToken.burn(100 * 1 ether);
    }

    function test_revertIfBurnerIsZeroAddress() public {
        address burner = address(0x0);
        vm.expectRevert(abi.encodeWithSelector(Burnable.BurnableUnauthorizedBurner.selector, address(burner)));
        vm.prank(burner);
        baseToken.burn(100 * 1 ether);
    }

    function test_burnFromOtherAddress() public {
        address burner = address(0x1);
        uint256 amount = 100 * 1 ether;
        baseToken.mint(burner, amount);
        uint256 totalSupply = baseToken.totalSupply();
        uint256 balanceBefore = baseToken.balanceOf(burner);
        vm.startPrank(burner);
        baseToken.approve(address(this), amount);
        vm.stopPrank();
        baseToken.burnFrom(burner, amount);
        uint256 balanceAfter = baseToken.balanceOf(burner);
        assertEq(balanceAfter, balanceBefore - amount);
        assertEq(totalSupply - amount, baseToken.totalSupply());
    }

    function test_burnFromZeroAmount() public {
        address burner = address(0x1);
        uint256 amount = 0;
        baseToken.mint(burner, amount);
        uint256 totalSupply = baseToken.totalSupply();
        uint256 balanceBefore = baseToken.balanceOf(burner);
        vm.startPrank(burner);
        baseToken.approve(address(this), amount);
        vm.stopPrank();
        baseToken.burnFrom(burner, amount);
        uint256 balanceAfter = baseToken.balanceOf(burner);
        assertEq(balanceAfter, balanceBefore - amount);
        assertEq(totalSupply - amount, baseToken.totalSupply());
    }

    function test_revertIfBurnFromNoAllowance() public {
        address burner = address(0x1);
        uint256 amount = 100 * 1 ether;
        baseToken.mint(burner, amount);
        uint256 allowance = baseToken.allowance(burner, address(this));
        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientAllowance.selector, address(this), allowance, amount));
        baseToken.burnFrom(burner, amount);
    }

    function test_revertIfBurnFromZeroAddress() public {
        address burner = address(0x0);
        uint256 amount = 100 * 1 ether;
        vm.expectRevert(abi.encodeWithSelector(Burnable.BurnableInvalidTokenOwner.selector, address(burner)));
        baseToken.burnFrom(burner, amount);
    }

    function test_setBurner() public {
        address burner = address(0x1);
        baseToken.setBurner(burner, true);
        assert(baseToken.isBurner(burner));
    }

    function test_revertIfSetBurnerSameValue() public {
        address burner = address(0x1);
        baseToken.setBurner(burner, true);
        vm.expectRevert(abi.encodeWithSelector(Burnable.BurnableSameValueAlreadySet.selector));
        baseToken.setBurner(burner, true);
    }

    function test_setBurnerShouldEmitEvent() public {
        address burner = address(0x1);
        vm.expectEmit(true, true, true, true);
        emit BurnerSet(burner, true);
        baseToken.setBurner(burner, true);
    }
}
