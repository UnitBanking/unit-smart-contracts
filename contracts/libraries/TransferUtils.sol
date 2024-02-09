// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../interfaces/IERC20.sol';

library TransferUtils {
    error TransferUtilsERC20TransferFromFailed(address token, address sender, address receiver, uint256 amount);
    error TransferUtilsERC20TransferFailed(address token, address receiver, uint256 amount);

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal returns (uint256) {
        (bool success, ) = address(token).call(abi.encodeCall(token.transferFrom, (from, to, amount)));
        if (!success) {
            revert TransferUtilsERC20TransferFromFailed(address(token), from, to, amount);
        }
        return amount;
    }

    function safeTransfer(IERC20 token, address to, uint256 amount) internal returns (uint256) {
        (bool success, ) = address(token).call(abi.encodeCall(token.transfer, (to, amount)));
        if (!success) {
            revert TransferUtilsERC20TransferFailed(address(token), to, amount);
        }
        return amount;
    }
}
