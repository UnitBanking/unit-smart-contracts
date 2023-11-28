// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import '../interfaces/IEthUsdOracle.sol';

contract EthUsdOracleMock is IEthUsdOracle {
    uint256 ethUsdPrice;

    constructor() {
        ethUsdPrice = 1e18;
    }

    function setEthUsdPrice(uint256 _ethUsdPrice) external {
        ethUsdPrice = _ethUsdPrice;
    }

    function getEthUsdPrice() external view returns (uint256) {
        return ethUsdPrice;
    }
}
