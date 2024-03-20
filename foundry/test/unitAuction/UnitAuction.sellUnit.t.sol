// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { UnitAuctionTestBase } from './UnitAuctionTestBase.t.sol';
import { IUnitAuction } from '../../../contracts/interfaces/IUnitAuction.sol';
import { IERC20 } from '../../../contracts/interfaces/IERC20.sol';
import { BondingCurve } from '../../../contracts/BondingCurve.sol';
import { TestUtils } from '../utils/TestUtils.t.sol';

abstract contract UnitAuctionSellUnitTest is UnitAuctionTestBase {
    function test_sellUnit_RevertsWhenInsufficientUserUnitBalance() public {
        // Arange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 unitAmount = unitToken.balanceOf(user) + 1;

        // Get RR below LOW_RR (i.e. in UNIT contraction range)
        vm.prank(bondingCurve);
        collateralToken.mint(1e18);

        vm.prank(user);
        unitToken.approve(address(unitAuctionProxy), unitAmount);

        // Act & Assert
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20.ERC20InsufficientBalance.selector,
                user,
                unitToken.balanceOf(user),
                unitAmount
            )
        );
        unitAuctionProxy.sellUnit(unitAmount);
        vm.stopPrank();
    }

    function test_sellUnit_RevertsWhenResultingReserveRatioOutOfRange() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 unitAmount = unitToken.balanceOf(user);

        // Get RR below LOW_RR (i.e. in UNIT contraction range)
        vm.prank(bondingCurve);
        collateralToken.mint(1e18);

        vm.prank(user);
        unitToken.approve(address(unitAuctionProxy), unitAmount);

        // Act & Assert
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IUnitAuction.UnitAuctionResultingReserveRatioOutOfRange.selector,
                899443158634848994882500124099660670
            )
        );
        unitAuctionProxy.sellUnit(unitAmount);
        vm.stopPrank();
    }

    function test_sellUnit_RevertsWhenReserveRatioNotIncreased() public {
        address user = _createUserAndMintUnitAndCollateralToken(1e18);

        // Get RR below LOW_RR (i.e. in UNIT contraction range)
        vm.prank(bondingCurve);
        collateralToken.mint(1e18);

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(IUnitAuction.UnitAuctionReserveRatioNotIncreased.selector);
        unitAuctionProxy.sellUnit(0);
    }

    function test_sellUnit_SuccessfullySelsUnitAfter33Minutes() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 collateralUnitBalanceBefore = collateralToken.balanceOf(user);

        uint256 unitAmount = 1e17;
        uint256 collateralAmount = 88322190268591359;

        vm.prank(bondingCurve);
        collateralToken.mint(1e18);

        vm.prank(user);
        unitToken.approve(address(unitAuctionProxy), unitAmount);

        unitAuctionProxy.refreshState();
        vm.warp(block.timestamp + 33 minutes);

        // Act & Assert
        vm.prank(user);
        unitAuctionProxy.sellUnit(unitAmount);
        uint256 collateralUnitBalanceAfter = collateralToken.balanceOf(user);
        assertEq(collateralUnitBalanceAfter - collateralUnitBalanceBefore, collateralAmount);
    }

    function test_sellUnit_SuccessfulBid(uint8 timeAfterAuctionStart) public {
        // timeAfterAuctionStart = bound(timeAfterAuctionStart, 0, 77);
        // require(timeAfterAuctionStart != 10);
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 userCollateralBalanceBefore = collateralToken.balanceOf(user);
        uint256 userUnitBalanceBefore = unitToken.balanceOf(user);
        uint256 auctionCollateralBalanceBefore = collateralToken.balanceOf(address(unitAuctionProxy));
        uint256 auctionUnitBalanceBefore = unitToken.balanceOf(address(unitAuctionProxy));
        uint256 bondingCurveCollateralBalanceBefore = collateralToken.balanceOf(bondingCurve);
        uint256 bondingCurveUnitBalanceBefore = unitToken.balanceOf(bondingCurve);
        assertEq(auctionCollateralBalanceBefore, 0);
        assertEq(auctionUnitBalanceBefore, 0);
        assertEq(bondingCurveUnitBalanceBefore, 0);

        // Get RR below LOW_RR (i.e. in UNIT contraction range)
        vm.prank(bondingCurve);
        collateralToken.mint(bondingCurveCollateralBalanceBefore);

        if (timeAfterAuctionStart > 0) {
            unitAuctionProxy.refreshState();
            vm.warp(block.timestamp + timeAfterAuctionStart);
        }

        // Act
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        uint256 unitSellAmount = 9;
        unitToken.approve(address(unitAuctionProxy), unitSellAmount);
        unitAuctionProxy.sellUnit(unitSellAmount);
        vm.stopPrank();

        // Assert
        uint256 userCollateralBalanceAfter = collateralToken.balanceOf(user);
        uint256 userUnitBalanceAfter = unitToken.balanceOf(user);
        uint256 auctionCollateralBalanceAfter = collateralToken.balanceOf(address(unitAuctionProxy));
        uint256 auctionUnitBalanceAfter = unitToken.balanceOf(address(unitAuctionProxy));
        uint256 bondingCurveCollateralBalanceAfter = collateralToken.balanceOf(bondingCurve);
        uint256 bondingCurveUnitBalanceAfter = unitToken.balanceOf(bondingCurve);
        assertEq(userCollateralBalanceAfter, userCollateralBalanceBefore + unitSellAmount);
        assertEq(userUnitBalanceAfter, userUnitBalanceBefore - unitSellAmount);
        assertEq(auctionCollateralBalanceAfter, auctionCollateralBalanceBefore);
        assertEq(auctionUnitBalanceAfter, auctionUnitBalanceBefore);
        assertEq(bondingCurveCollateralBalanceAfter, bondingCurveCollateralBalanceBefore * 2 - unitSellAmount);
        assertEq(bondingCurveUnitBalanceAfter, bondingCurveUnitBalanceBefore);
    }

    function test_sellUnit_SuccessfulLargestBidAtAuctionStart() public {
        _test_sellUnit_SuccessfulLargestBid(0 seconds);
    }

    function test_sellUnit_SuccessfulLargestBidMidAuction() public {
        _test_sellUnit_SuccessfulLargestBid(unitAuctionProxy.contractionAuctionMaxDuration() / 2);
    }

    function test_sellUnit_SuccessfulLargestBidAtLastSecond() public {
        _test_sellUnit_SuccessfulLargestBid(unitAuctionProxy.contractionAuctionMaxDuration() - 1);
    }

    function test_sellUnit_SuccessfulLargestBidAtAuctionTermination() public {
        _test_sellUnit_SuccessfulLargestBid(unitAuctionProxy.contractionAuctionMaxDuration());
    }

    function test_sellUnit_SuccessfulLargestBidBeyondAuctionTermination() public {
        _test_sellUnit_SuccessfulLargestBid(unitAuctionProxy.contractionAuctionMaxDuration() + 1);
    }

    function _test_sellUnit_SuccessfulLargestBid(uint256 timeAfterAuctionStart) internal {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 userCollateralBalanceBefore = collateralToken.balanceOf(user);
        uint256 userUnitBalanceBefore = unitToken.balanceOf(user);
        uint256 auctionCollateralBalanceBefore = collateralToken.balanceOf(address(unitAuctionProxy));
        uint256 auctionUnitBalanceBefore = unitToken.balanceOf(address(unitAuctionProxy));
        uint256 bondingCurveCollateralBalanceBefore = collateralToken.balanceOf(bondingCurve);
        uint256 bondingCurveUnitBalanceBefore = unitToken.balanceOf(bondingCurve);
        assertEq(auctionCollateralBalanceBefore, 0);
        assertEq(auctionUnitBalanceBefore, 0);
        assertEq(bondingCurveUnitBalanceBefore, 0);

        // Get RR below LOW_RR (i.e. in UNIT contraction range)
        vm.prank(bondingCurve);
        collateralToken.mint(bondingCurveCollateralBalanceBefore);

        if (timeAfterAuctionStart > 0) {
            unitAuctionProxy.refreshState();
            vm.warp(block.timestamp + timeAfterAuctionStart);
        }

        // Act
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        (uint256 maxUnitSellAmount, uint256 collateralAmount) = unitAuctionProxy.getMaxSellUnitAmount();
        unitToken.approve(address(unitAuctionProxy), maxUnitSellAmount);
        unitAuctionProxy.sellUnit(maxUnitSellAmount);
        vm.stopPrank();

        // Assert
        uint256 userCollateralBalanceAfter = collateralToken.balanceOf(user);
        uint256 userUnitBalanceAfter = unitToken.balanceOf(user);
        uint256 bondingCurveCollateralBalanceAfter = collateralToken.balanceOf(bondingCurve);
        uint256 bondingCurveUnitBalanceAfter = unitToken.balanceOf(bondingCurve);
        assertEq(userCollateralBalanceAfter, userCollateralBalanceBefore + collateralAmount);
        assertEq(userUnitBalanceAfter, userUnitBalanceBefore - maxUnitSellAmount);
        assertEq(bondingCurveCollateralBalanceAfter, bondingCurveCollateralBalanceBefore * 2 - collateralAmount);
        assertEq(bondingCurveUnitBalanceAfter, bondingCurveUnitBalanceBefore);

        uint256 auctionCollateralBalanceAfter = collateralToken.balanceOf(address(unitAuctionProxy));
        uint256 auctionUnitBalanceAfter = unitToken.balanceOf(address(unitAuctionProxy));
        assertEq(auctionCollateralBalanceAfter, auctionCollateralBalanceBefore);
        assertEq(auctionUnitBalanceAfter, auctionUnitBalanceBefore);
    }

    function test_sellUnit_RevertsOnTooLargeBidAtAuctionStart() public {
        _test_sellUnit_RevertsOnTooLargeBid(0 seconds, 4000000000000000006);
    }

    function test_sellUnit_RevertsOnTooLargeBidMidAuction() public {
        _test_sellUnit_RevertsOnTooLargeBid(unitAuctionProxy.contractionAuctionMaxDuration() / 2, 4000000000000000001);
    }

    function test_sellUnit_RevertsOnTooLargeBidAtLastSecond() public {
        _test_sellUnit_RevertsOnTooLargeBid(unitAuctionProxy.contractionAuctionMaxDuration() - 1, 4000000000000000001);
    }

    function test_sellUnit_RevertsOnTooLargeBidAtAuctionTermination() public {
        _test_sellUnit_RevertsOnTooLargeBid(unitAuctionProxy.contractionAuctionMaxDuration(), 4000000000000000006);
    }

    function test_sellUnit_RevertsOnTooLargeBidBeyondAuctionTermination() public {
        _test_sellUnit_RevertsOnTooLargeBid(unitAuctionProxy.contractionAuctionMaxDuration() + 1, 4000000000000000004);
    }

    function _test_sellUnit_RevertsOnTooLargeBid(uint256 timeAfterAuctionStart, uint256 extectedReserveRatio) internal {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 userCollateralBalanceBefore = collateralToken.balanceOf(user);
        uint256 userUnitBalanceBefore = unitToken.balanceOf(user);
        uint256 auctionCollateralBalanceBefore = collateralToken.balanceOf(address(unitAuctionProxy));
        uint256 auctionUnitBalanceBefore = unitToken.balanceOf(address(unitAuctionProxy));
        uint256 bondingCurveCollateralBalanceBefore = collateralToken.balanceOf(bondingCurve);
        uint256 bondingCurveUnitBalanceBefore = unitToken.balanceOf(bondingCurve);
        assertEq(auctionCollateralBalanceBefore, 0);
        assertEq(auctionUnitBalanceBefore, 0);
        assertEq(bondingCurveUnitBalanceBefore, 0);

        // Get RR below LOW_RR (i.e. in UNIT contraction range)
        vm.prank(bondingCurve);
        collateralToken.mint(bondingCurveCollateralBalanceBefore);
        assertGt(BondingCurve(bondingCurve).getReserveRatio(), TestUtils.CRITICAL_RR);
        assertLe(BondingCurve(bondingCurve).getReserveRatio(), TestUtils.LOW_RR);

        // Correct bonding curve's before balance
        assertEq(collateralToken.balanceOf(bondingCurve), bondingCurveCollateralBalanceBefore * 2);
        bondingCurveCollateralBalanceBefore = collateralToken.balanceOf(bondingCurve);

        if (timeAfterAuctionStart > 0) {
            unitAuctionProxy.refreshState();
            vm.warp(block.timestamp + timeAfterAuctionStart);
        }

        // Act
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        (uint256 maxUnitSellAmount, uint256 collateralAmount) = unitAuctionProxy.getMaxSellUnitAmount();
        uint256 tooHighUnitSellAmount = maxUnitSellAmount + 1;
        unitToken.approve(address(unitAuctionProxy), tooHighUnitSellAmount);
        vm.expectRevert(
            abi.encodeWithSelector(
                IUnitAuction.UnitAuctionResultingReserveRatioOutOfRange.selector,
                extectedReserveRatio
            )
        );
        unitAuctionProxy.sellUnit(tooHighUnitSellAmount);
        vm.stopPrank();

        // Assert
        uint256 expectedCollateralAmount = (maxUnitSellAmount * unitAuctionProxy.getCurrentSellUnitPrice()) /
            unitAuctionProxy.STANDARD_PRECISION();
        assertEq(
            collateralAmount,
            expectedCollateralAmount,
            'unitAuctionProxy.getMaxSellUnitAmount() returned invalid collateral amount'
        );

        uint256 userCollateralBalanceAfter = collateralToken.balanceOf(user);
        uint256 userUnitBalanceAfter = unitToken.balanceOf(user);
        uint256 bondingCurveCollateralBalanceAfter = collateralToken.balanceOf(bondingCurve);
        uint256 bondingCurveUnitBalanceAfter = unitToken.balanceOf(bondingCurve);
        assertEq(userCollateralBalanceAfter, userCollateralBalanceBefore, 'user collateral has changed');
        assertEq(userUnitBalanceAfter, userUnitBalanceBefore, 'user UNIT has changed');
        assertEq(
            bondingCurveCollateralBalanceAfter,
            bondingCurveCollateralBalanceBefore,
            'bonding curve collateral has changed'
        );
        assertEq(bondingCurveUnitBalanceAfter, bondingCurveUnitBalanceBefore, 'bonding curve UNIT has changed');

        uint256 auctionCollateralBalanceAfter = collateralToken.balanceOf(address(unitAuctionProxy));
        uint256 auctionUnitBalanceAfter = unitToken.balanceOf(address(unitAuctionProxy));
        assertEq(
            auctionCollateralBalanceAfter,
            auctionCollateralBalanceBefore,
            'auction contract collateral has changed'
        );
        assertEq(auctionUnitBalanceAfter, auctionUnitBalanceBefore, 'auction contract UNIT has changed');
    }

    function test_sellUnit_RevertsWhenNotInContraction() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);

        vm.prank(bondingCurve);
        collateralToken.mint(2e18);
        uint256 initialRR = BondingCurve(bondingCurve).getReserveRatio();
        assertGt(initialRR, 3 * TestUtils.STANDARD_PRECISION);

        // Act & Assert
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(IUnitAuction.UnitAuctionInitialReserveRatioOutOfRange.selector, initialRR)
        );
        unitAuctionProxy.sellUnit(1e18);
    }

    function test_sellUnit_GetMaxSellUnitAmountAtAuctionStart() public {
        _test_sellUnit_GetMaxSellUnitAmount(0 seconds);
    }

    function test_sellUnit_GetMaxSellUnitAmountMidAuction() public {
        _test_sellUnit_GetMaxSellUnitAmount(unitAuctionProxy.contractionAuctionMaxDuration() / 2);
    }

    function test_sellUnit_GetMaxSellUnitAmountAtLastSecond() public {
        _test_sellUnit_GetMaxSellUnitAmount(unitAuctionProxy.contractionAuctionMaxDuration() - 1);
    }

    function test_sellUnit_GetMaxSellUnitAmountAtAuctionTermination() public {
        _test_sellUnit_GetMaxSellUnitAmount(unitAuctionProxy.contractionAuctionMaxDuration());
    }

    function test_sellUnit_GetMaxSellUnitAmountBeyondAuctionTermination() public {
        _test_sellUnit_GetMaxSellUnitAmount(unitAuctionProxy.contractionAuctionMaxDuration() + 1);
    }

    function _test_sellUnit_GetMaxSellUnitAmount(uint256 timeAfterAuctionStart) internal {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 bondingCurveCollateralBalanceBefore = collateralToken.balanceOf(bondingCurve);
        vm.prank(bondingCurve);
        collateralToken.mint(bondingCurveCollateralBalanceBefore);

        if (timeAfterAuctionStart > 0) {
            unitAuctionProxy.refreshState();
            vm.warp(block.timestamp + timeAfterAuctionStart);
        }

        // Act
        vm.prank(user);
        (uint256 maxUnitSellAmount, uint256 collateralAmount) = unitAuctionProxy.getMaxSellUnitAmount();

        // Assert
        uint256 expectedMaxUnitSellAmount = BondingCurve(bondingCurve).quoteUnitBurnAmountForHighRR(
            unitAuctionProxy.getCurrentSellUnitPrice()
        );
        uint256 expectedCollateralAmount = (expectedMaxUnitSellAmount * unitAuctionProxy.getCurrentSellUnitPrice()) /
            unitAuctionProxy.STANDARD_PRECISION();
        assertEq(maxUnitSellAmount, expectedMaxUnitSellAmount);
        assertEq(collateralAmount, expectedCollateralAmount);
    }

    function test_sellUnit_ChecksUnitPricingAtTheBeginningOfAuction() public {
        _test_sellUnit_ChecksUnitPricing(0, 314794767497862116);
    }

    function test_sellUnit_ChecksUnitPricingInTheMiddleOfAuction() public {
        _test_sellUnit_ChecksUnitPricing(unitAuctionProxy.contractionAuctionMaxDuration() / 2, 210588809201578605);
    }

    function test_sellUnit_ChecksUnitPricingAtTheEndOfAuction() public {
        _test_sellUnit_ChecksUnitPricing(unitAuctionProxy.contractionAuctionMaxDuration(), 140877966026675010);
    }

    function _test_sellUnit_ChecksUnitPricing(uint256 timeAfterAuctionStart, uint256 expectedCollateralAmount) private {
        // Arrange
        address user = _setUpBondingCurveAndUnitAuction();
        uint256 userCollateralBalanceBefore = collateralToken.balanceOf(user);

        // set the end of the contraction auction
        vm.warp(block.timestamp + timeAfterAuctionStart);

        uint256 collateralAmount = expectedCollateralAmount;
        uint256 unitAmount = 1e18;

        // Act & Assert
        vm.expectEmit();
        emit IUnitAuction.UnitSold(user, unitAmount, collateralAmount);
        vm.prank(user);
        unitAuctionProxy.sellUnit(unitAmount);

        uint256 userCollateralBalanceAfter = collateralToken.balanceOf(user);
        assertEq(userCollateralBalanceAfter - userCollateralBalanceBefore, collateralAmount);
    }

    function _setUpBondingCurveAndUnitAuction() private returns (address) {
        // set collateral-usd price
        collateralUsdOracle.setCollateralUsdPrice(35e17);
        vm.warp(block.timestamp + 356 days);

        vm.prank(bondingCurve);
        collateralToken.mint(10e18);

        // mint collateral and unit tokens
        address user = _createUserWithPrivateKeyAndMintUnitAndCollateralTokens(100, 1e18);
        _createUserWithPrivateKeyAndMintUnitAndCollateralTokens(200, 10 * 1e18);

        // start contraction auction
        unitAuctionProxy.refreshState();

        return user;
    }
}

contract UnitAuctionSellUnitTest_18DecimalCollateral is UnitAuctionSellUnitTest {

}

// contract UnitAuctionSellUnitTest_17DecimalCollateral is UnitAuctionSellUnitTest {
//     function setUp() public override {
//         _setUp(17);
//     }
// }
