// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import './BaseTokenTestBase.t.sol';
import '../utils/SigUtils.sol';
import { IERC20 } from '../../../contracts/interfaces/IERC20.sol';
import { IERC20Permit } from '../../../contracts/interfaces/IERC20Permit.sol';

contract BaseTokenPermitTest is BaseTokenTestBase {
    SigUtils internal sigUtils;
    uint256 internal ownerPrivateKey = 0xA11CE;
    uint256 internal spenderPrivateKey = 0xB0B;

    address internal owner = vm.addr(ownerPrivateKey);
    address internal spender = vm.addr(spenderPrivateKey);

    function setUp() public override {
        super.setUp();
        sigUtils = new SigUtils(
            keccak256(
                abi.encode(
                    baseToken.DOMAIN_TYPEHASH(),
                    keccak256(bytes(baseToken.name())),
                    block.chainid,
                    address(baseToken)
                )
            )
        );
    }

    function test_permit_ValidPermit() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        baseToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        assertEq(baseToken.allowance(owner, spender), 1);
        assertEq(baseToken.nonces(owner), 1);
    }

    function test_permit_RevertsIfExpiredPermit() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: baseToken.nonces(owner),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        vm.warp(1 days + 1 seconds); // fast forward one second past the deadline

        vm.expectRevert(abi.encodeWithSelector(IERC20Permit.ERC20PermitSignatureExpired.selector, permit.deadline));
        baseToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function test_permit_RevertsIfInvalidSigner() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: baseToken.nonces(owner),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(spenderPrivateKey, digest); // spender signs owner's approval

        vm.expectRevert(abi.encodeWithSelector(IERC20Permit.ERC20InvalidSigner.selector, spender, owner));
        baseToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function test_permit_RevertsIfInvalidNonce() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: 1, // owner nonce stored on-chain is 0
            deadline: 1 days
        });
        SigUtils.Permit memory correctPermit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: 0, // owner nonce stored on-chain is 0
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        bytes32 expectedDigest = sigUtils.getTypedDataHash(correctPermit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        address signer = ecrecover(expectedDigest, v, r, s);

        vm.expectRevert(abi.encodeWithSelector(IERC20Permit.ERC20InvalidSigner.selector, signer, permit.owner));
        baseToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function test_permit_RevertsSignatureReplay() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: 0,
            deadline: 1 days
        });

        SigUtils.Permit memory correctPermit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: 1,
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        bytes32 expectedDigest = sigUtils.getTypedDataHash(correctPermit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        baseToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
        address signer = ecrecover(expectedDigest, v, r, s);

        vm.expectRevert(abi.encodeWithSelector(IERC20Permit.ERC20InvalidSigner.selector, signer, permit.owner));
        baseToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }
}
