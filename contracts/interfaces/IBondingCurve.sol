// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { UD60x18 } from '@prb/math/src/UD60x18.sol';

interface IBondingCurve {
    function getInternalPrice() external view returns (UD60x18);
}
