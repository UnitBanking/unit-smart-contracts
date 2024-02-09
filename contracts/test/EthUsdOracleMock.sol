// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../interfaces/IEthUsdOracle.sol';

contract EthUsdOracleMock is IEthUsdOracle {
    uint256 private constant ETHUSD_PRICE_PRECISION = 1e18;
    uint256 ethUsdPrice;

    constructor() {
        ethUsdPrice = ETHUSD_PRICE_PRECISION;
    }

    function getEthUsdPricePrecision() external pure returns (uint256) {
        return ETHUSD_PRICE_PRECISION;
    }

    function setEthUsdPrice(uint256 _ethUsdPrice) external {
        ethUsdPrice = _ethUsdPrice;
    }

    function getEthUsdPrice() external view returns (uint256) {
        return ethUsdPrice;
    }
}
