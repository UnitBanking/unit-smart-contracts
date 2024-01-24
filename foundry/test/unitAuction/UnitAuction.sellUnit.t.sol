// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { UnitAuctionTestBase } from './UnitAuctionTestBase.t.sol';
import { TestUtils } from '../utils/TestUtils.t.sol';
import { IUnitAuction } from '../../../contracts/interfaces/IUnitAuction.sol';

contract UnitAuctionSellUnitTest is UnitAuctionTestBase {
    function test_sellUnit_SuccessfulBid() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 userCollateralBalanceBefore = collateralERC20Token.balanceOf(user);
        uint256 userUnitBalanceBefore = unitToken.balanceOf(user);
        uint256 auctionCollateralBalanceBefore = collateralERC20Token.balanceOf(address(unitAuctionProxy));
        uint256 auctionUnitBalanceBefore = unitToken.balanceOf(address(unitAuctionProxy));
        uint256 bondingCurveCollateralBalanceBefore = collateralERC20Token.balanceOf(address(bondingCurveProxy));
        uint256 bondingCurveUnitBalanceBefore = unitToken.balanceOf(address(bondingCurveProxy));
        assertEq(auctionCollateralBalanceBefore, 0);
        assertEq(auctionUnitBalanceBefore, 0);
        assertEq(bondingCurveUnitBalanceBefore, 0);

        // Get RR to 2 (i.e. in UNIT contraction range)
        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(bondingCurveCollateralBalanceBefore);

        // Act
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        uint256 unitSellAmount = 9;
        unitToken.approve(address(unitAuctionProxy), unitSellAmount);
        unitAuctionProxy.sellUnit(unitSellAmount);
        vm.stopPrank();

        // Assert
        uint256 userCollateralBalanceAfter = collateralERC20Token.balanceOf(user);
        uint256 userUnitBalanceAfter = unitToken.balanceOf(user);
        uint256 auctionCollateralBalanceAfter = collateralERC20Token.balanceOf(address(unitAuctionProxy));
        uint256 auctionUnitBalanceAfter = unitToken.balanceOf(address(unitAuctionProxy));
        uint256 bondingCurveCollateralBalanceAfter = collateralERC20Token.balanceOf(address(bondingCurveProxy));
        uint256 bondingCurveUnitBalanceAfter = unitToken.balanceOf(address(bondingCurveProxy));
        assertEq(userCollateralBalanceAfter, userCollateralBalanceBefore + unitSellAmount);
        assertEq(userUnitBalanceAfter, userUnitBalanceBefore - unitSellAmount);
        assertEq(auctionCollateralBalanceAfter, auctionCollateralBalanceBefore);
        assertEq(auctionUnitBalanceAfter, auctionUnitBalanceBefore);
        assertEq(bondingCurveCollateralBalanceAfter, bondingCurveCollateralBalanceBefore * 2 - unitSellAmount);
        assertEq(bondingCurveUnitBalanceAfter, bondingCurveUnitBalanceBefore);
    }

    function test_sellUnit_RevertsWhenNotInContraction() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);

        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(2e18);
        uint256 initialRR = bondingCurveProxy.getReserveRatio();
        assertGt(initialRR, 3 * TestUtils.RR_PRECISION);

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IUnitAuction.UnitAuctionInitialReserveRatioOutOfRange.selector, initialRR)
        );
        unitAuctionProxy.sellUnit(1e18);
    }
}
