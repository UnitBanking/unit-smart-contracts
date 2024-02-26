// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './BaseTokenTestCase.t.sol';
import '../utils/SigUtils.sol';

contract BaseTokenPermitTest is BaseTokenBaseTest {
    SigUtils internal sigUtils;
    uint256 internal ownerPrivateKey = 0xA11CE;
    uint256 internal spenderPrivateKey = 0xB0B;

    address internal owner = vm.addr(ownerPrivateKey);
    address internal spender = vm.addr(spenderPrivateKey);

    error ERC20PermitSignatureExpired(uint256 expiry);
    error ERC20InvalidSigner(address signer, address owner);

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

    function test_permit() public {
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

    function test_revertIfExpiredPermit() public {
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

        vm.expectRevert(abi.encodeWithSelector(ERC20PermitSignatureExpired.selector, permit.deadline));
        baseToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function test_revertIfInvalidSigner() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: baseToken.nonces(owner),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(spenderPrivateKey, digest); // spender signs owner's approval

        vm.expectRevert(abi.encodeWithSelector(ERC20InvalidSigner.selector, spender, owner));
        baseToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testRevert_InvalidNonce() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: 1, // owner nonce stored on-chain is 0
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        vm.expectRevert();
        baseToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testRevert_SignatureReplay() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        baseToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.expectRevert();
        baseToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }
}
