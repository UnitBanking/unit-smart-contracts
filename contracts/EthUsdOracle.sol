// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './interfaces/IEthUsdOracle.sol';

contract EthUsdOracle is IEthUsdOracle {
    function getEthUsdPrice() external pure returns (uint256) {
        return 1;
    }
}
