// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './BaseTokenTestBase.t.sol';
import { IERC20 } from '../../../contracts/interfaces/IERC20.sol';
import { Ownable } from '../../../contracts/abstracts/Ownable.sol';

contract BaseTokenOwnerTest is BaseTokenTestBase {
    event OwnerSet(address indexed owner);

    function test_setOwner() public {
        address newOwner = address(0x1);
        baseToken.setOwner(newOwner);
        assertEq(baseToken.owner(), newOwner);
    }

    function test_revertIfUnauthorizedOwner() public {
        address unauthorizedOwner = address(0x1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedOwner.selector, unauthorizedOwner));
        vm.prank(unauthorizedOwner);
        baseToken.setOwner(address(0x2));
    }

    function test_revertIfSetOwnerWithZeroAddress() public {
        address newOwner = address(0x0);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, newOwner));
        baseToken.setOwner(newOwner);
    }

    function test_revertIfSetOwnerWithSameValue() public {
        address newOwner = address(0x1);
        baseToken.setOwner(newOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableSameValueAlreadySet.selector));
        vm.prank(newOwner);
        baseToken.setOwner(newOwner);
    }

    function test_setOwnerShouldEmitEvent() public {
        address newOwner = address(0x1);
        vm.expectEmit(true, true, true, true);
        emit OwnerSet(newOwner);
        baseToken.setOwner(newOwner);
    }
}
