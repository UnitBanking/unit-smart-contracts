// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import './BaseTokenTestBase.t.sol';
import { IERC20 } from '../../../contracts/interfaces/IERC20.sol';
import { Ownable } from '../../../contracts/abstracts/Ownable.sol';

contract BaseTokenOwnerTest is BaseTokenTestBase {
    function test_setOwner_SetOwner() public {
        address newOwner = address(0x1);
        baseToken.setOwner(newOwner);
        assertEq(baseToken.owner(), newOwner);
    }

    function test_setOwner_RevertsIfUnauthorizedOwner() public {
        address unauthorizedOwner = address(0x1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedOwner.selector, unauthorizedOwner));
        vm.prank(unauthorizedOwner);
        baseToken.setOwner(address(0x2));
    }

    function test_setOwner_RevertsIfSetOwnerWithZeroAddress() public {
        address newOwner = address(0x0);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, newOwner));
        baseToken.setOwner(newOwner);
    }

    function test_setOwner_RevertsIfSetOwnerWithSameValue() public {
        address newOwner = address(0x1);
        baseToken.setOwner(newOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableSameValueAlreadySet.selector));
        vm.prank(newOwner);
        baseToken.setOwner(newOwner);
    }

    function test_setOwner_SetOwnerShouldEmitEvent() public {
        address newOwner = address(0x1);
        vm.expectEmit(true, true, true, true);
        emit Ownable.OwnerSet(newOwner);
        baseToken.setOwner(newOwner);
    }
}
