// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import "../interfaces/IERC20.sol";

library TransferHelper {

    error TransferHelperEthTransferFailed(address receiver, uint256 amount);
    error TransferHelperERC20TransferFailed(address token, address receiver, uint256 amount);

    function transferEth(address receiver, uint256 amount) internal {
        (bool success, ) = receiver.call{ value: amount }('');
        if (!success) {
            revert TransferHelperEthTransferFailed(receiver, amount);
        }
    }

    function safeTransferFromERC20(IERC20 token, address from, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeCall(token.transferFrom, (from, to, amount)));
        if (!success) {
            revert TransferHelperERC20TransferFailed(address(token), to, amount);
        }
    }
}
