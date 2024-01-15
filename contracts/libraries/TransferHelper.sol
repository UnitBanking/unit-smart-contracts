// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import '../interfaces/IERC20.sol';
import 'hardhat/console.sol';

library TransferHelper {
    error TransferHelperEthTransferFailed(address receiver, uint256 amount);
    error TransferHelperERC20TransferFailed(address token, address from, address receiver, uint256 amount);

    function transferEth(address receiver, uint256 amount) internal {
        (bool success, ) = receiver.call{ value: amount }('');
        if (!success) {
            revert TransferHelperEthTransferFailed(receiver, amount);
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal returns (uint256) {
        uint256 balanceBefore = token.balanceOf(to);
        (bool success, ) = address(token).call(abi.encodeCall(token.transferFrom, (from, to, amount)));
        if (!success) {
            revert TransferHelperERC20TransferFailed(address(token), from, to, amount);
        }
        uint256 balanceAfter = token.balanceOf(to);
        return balanceAfter - balanceBefore;
    }
}
