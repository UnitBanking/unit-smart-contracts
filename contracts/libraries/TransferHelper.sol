// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import '../interfaces/IERC20.sol';

library TransferHelper {
    error TransferHelperERC20TransferFailed(address token, address receiver, uint256 amount);

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal returns (uint256) {
        (bool success, ) = address(token).call(abi.encodeCall(token.transferFrom, (from, to, amount)));
        if (!success) {
            revert TransferHelperERC20TransferFailed(address(token), to, amount);
        }
        return amount;
    }
}
