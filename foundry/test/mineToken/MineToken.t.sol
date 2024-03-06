pragma solidity 0.8.21;

import './MineTokenTestBase.t.sol';

contract MineTokenTest is MineTokenTestBase {
    function test_initialize() public {
        assertEq(mineToken.owner(), address(this));
    }

    function test_info_CorrectTokenInfo() public {
        assertEq(mineToken.name(), 'Mine');
        assertEq(mineToken.symbol(), 'MINE');
        assertEq(mineToken.decimals(), 18);
        assertEq(mineToken.MAX_SUPPLY(), 1022700000 * 1 ether);
    }
}
