// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import '../interfaces/IERC20.sol';

library TransferUtils {
    error TransferUtilsERC20TransferFromFailed(address token, address sender, address receiver, uint256 amount);
    error TransferUtilsERC20TransferFailed(address token, address receiver, uint256 amount);

    /**
     * @notice Transfers `token` from `from` to `to` without restriction. Reverts on failure.
     * @dev For tokens that may not transfer the requested amount (e.g. rebasing tokens), `balanceOf` should be used
     * for snapshots to calculate the actual amount transferred.
     * @return amount The token amount that was transferred.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal returns (uint256) {
        (bool success, ) = address(token).call(abi.encodeCall(token.transferFrom, (from, to, amount)));
        if (!success) {
            revert TransferUtilsERC20TransferFromFailed(address(token), from, to, amount);
        }
        return amount;
    }

    /**
     * @notice Transfers `token` from the contract to `to` without restriction. Reverts on failure.
     * @dev For tokens that may not transfer the requested amount (e.g. rebasing tokens), `balanceOf` should be used
     * for snapshots to calculate the actual amount transferred.
     * @return amount The token amount that was transferred.
     */
    function safeTransfer(IERC20 token, address to, uint256 amount) internal returns (uint256) {
        (bool success, ) = address(token).call(abi.encodeCall(token.transfer, (to, amount)));
        if (!success) {
            revert TransferUtilsERC20TransferFailed(address(token), to, amount);
        }
        return amount;
    }
}
