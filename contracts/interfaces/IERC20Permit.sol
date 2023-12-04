// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

interface IERC20Permit {
    error ERC20InvalidPermitSignature(address signature);
    error ERC20PermitSignatureExpired(uint256 expiry);
    error ERC20InvalidSigner(address signer, address owner);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
