pragma solidity 0.8.23;

import './UnitTokenTestBase.t.sol';

contract UnitTokenTest is UnitTokenTestBase {
    function test_mint_UserCanMint() public {
        uint256 balanceBefore = unitToken.balanceOf(address(this));
        uint256 totalSupply = unitToken.totalSupply();
        unitToken.mint(address(this), 100 * 1 ether);
        uint256 balanceAfter = unitToken.balanceOf(address(this));
        assertEq(totalSupply + 100 * 1 ether, unitToken.totalSupply());
        assertEq(balanceAfter, balanceBefore + 100 * 1 ether);
    }

    function test_info_CorrectTokenInfo() public {
        assertEq(unitToken.name(), 'Unit');
        assertEq(unitToken.symbol(), 'UNIT');
        assertEq(unitToken.decimals(), 18);
    }

    function test_initialize() public {
        assertEq(unitToken.owner(), address(this));
    }
}
