// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

library TransferHelper {
    error TransferHelperEthTransferFailed(address receiver, uint256 amount);

    function transferEth(address receiver, uint256 amount) internal {
        (bool success, ) = receiver.call{ value: amount }('');
        if (!success) {
            revert TransferHelperEthTransferFailed(receiver, amount);
        }
    }
}