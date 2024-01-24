// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import { UnitAuctionTestBase } from './UnitAuctionTestBase.t.sol';
import { UnitAuction } from '../../../contracts/auctions/UnitAuction.sol';
import { IUnitAuction } from '../../../contracts/interfaces/IUnitAuction.sol';
import { TestUtils } from '../utils/TestUtils.t.sol';
import { Ownable } from '../../../contracts/abstracts/Ownable.sol';

contract UnitAuctionTest is UnitAuctionTestBase {
    function test_constructor_stateVariablesSetCorrectly() public {
        // Arrange & Act & Assert
        assertEq(unitAuctionImplementation.initialized(), true);
        assertEq(address(unitAuctionProxy.bondingCurve()), address(bondingCurveProxy));
        assertEq(address(unitAuctionProxy.unitToken()), address(unitToken));
    }

    function test_receive_NoDirectTransfer() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 balanceBefore = address(unitAuctionProxy).balance;

        // Act
        vm.deal(user, 10 ether);
        vm.prank(user);
        bool success = TestUtils.sendEth(address(unitAuctionProxy), 1 ether);

        // Assert
        uint256 balanceAfter = address(unitAuctionProxy).balance;
        assertEq(success, false);
        assertEq(balanceAfter, balanceBefore);
    }

    function test_initialize_stateVariablesSetCorrectly() public {
        // Arrange & Act & Assert
        assertEq(unitAuctionProxy.owner(), 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);
        assertEq(unitAuctionProxy.contractionAuctionMaxDuration(), 2 hours);
        assertEq(unitAuctionProxy.expansionAuctionMaxDuration(), 23 hours);
        assertEq(unitAuctionProxy.startPriceBuffer(), 11_000);
        assertEq(unitAuctionProxy.initialized(), true);
    }

    /**
     * ================ setContractionAuctionMaxDuration() ================
     */

    function test_setContractionAuctionMaxDuration_ownerCanSet() public {
        // Arrange
        uint256 contractionMaxDurationBefore = unitAuctionProxy.contractionAuctionMaxDuration();

        // Act
        unitAuctionProxy.setContractionAuctionMaxDuration(contractionMaxDurationBefore + 1 hours);

        // Assert
        uint256 contractionMaxDurationAfter = unitAuctionProxy.contractionAuctionMaxDuration();
        assertEq(contractionMaxDurationAfter, contractionMaxDurationBefore + 1 hours);
    }

    function test_setContractionAuctionMaxDuration_notOwnerCannotSet() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 contractionMaxDurationBefore = unitAuctionProxy.contractionAuctionMaxDuration();

        // Act
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedOwner.selector, user));
        unitAuctionProxy.setContractionAuctionMaxDuration(contractionMaxDurationBefore + 1 hours);

        // Assert
        uint256 contractionMaxDurationAfter = unitAuctionProxy.contractionAuctionMaxDuration();
        assertEq(contractionMaxDurationAfter, contractionMaxDurationBefore);
    }

    /**
     * ================ setExpansionAuctionMaxDuration() ================
     */

    function test_setExpansionAuctionMaxDuration_ownerCanSet() public {
        // Arrange
        uint256 expansionMaxDurationBefore = unitAuctionProxy.expansionAuctionMaxDuration();

        // Act
        unitAuctionProxy.setExpansionAuctionMaxDuration(expansionMaxDurationBefore + 1 hours);

        // Assert
        uint256 expansionMaxDurationAfter = unitAuctionProxy.expansionAuctionMaxDuration();
        assertEq(expansionMaxDurationAfter, expansionMaxDurationBefore + 1 hours);
    }

    function test_setExpansionAuctionMaxDuration_notOwnerCannotSet() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 expansionMaxDurationBefore = unitAuctionProxy.expansionAuctionMaxDuration();

        // Act
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedOwner.selector, user));
        unitAuctionProxy.setExpansionAuctionMaxDuration(expansionMaxDurationBefore + 1 hours);

        // Assert
        uint256 expansionMaxDurationAfter = unitAuctionProxy.expansionAuctionMaxDuration();
        assertEq(expansionMaxDurationAfter, expansionMaxDurationBefore);
    }

    /**
     * ================ setStartPriceBuffer() ================
     */

    function test_setStartPriceBuffer_ownerCanSet() public {
        // Arrange
        uint256 startPriceBufferBefore = unitAuctionProxy.startPriceBuffer();

        // Act
        unitAuctionProxy.setStartPriceBuffer(startPriceBufferBefore + 1);

        // Assert
        uint256 startPriceBufferAfter = unitAuctionProxy.startPriceBuffer();
        assertEq(startPriceBufferAfter, startPriceBufferBefore + 1);
    }

    function test_setStartPriceBuffer_notOwnerCannotSet() public {
        // Arrange
        address user = _createUserAndMintUnitAndCollateralToken(1e18);
        uint256 startPriceBufferBefore = unitAuctionProxy.startPriceBuffer();

        // Act
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedOwner.selector, user));
        unitAuctionProxy.setStartPriceBuffer(startPriceBufferBefore + 1);

        // Assert
        uint256 startPriceBufferAfter = unitAuctionProxy.startPriceBuffer();
        assertEq(startPriceBufferAfter, startPriceBufferBefore);
    }

    /**
     * ================ _startContractionAuction() ================
     */

    function test_startContractionAuction_SuccessfullyStarts() public {
        // Arrnage
        uint256 mintPrice = bondingCurveProxy.getMintPrice();
        uint216 price = uint216(
            (mintPrice * unitAuctionProxy.startPriceBuffer()) / unitAuctionProxy.START_PRICE_BUFFER_PRECISION()
        );

        // Act
        vm.expectEmit();
        emit IUnitAuction.StartAuction(AUCTION_VARIANT_CONTRACTION, uint32(block.timestamp), price);
        unitAuctionProxy.exposed_startContractionAuction();

        // Assert
        (uint32 startTime, uint216 startPrice, uint8 variant) = unitAuctionProxy.auctionState();
        assertEq(startTime, block.timestamp);
        assertEq(startPrice, price);
        assertEq(variant, AUCTION_VARIANT_CONTRACTION);
    }

    /**
     * ================ _startExpansionAuction() ================
     */

    function test_startExpansionAuction_SuccessfullyStarts() public {
        // Arrnage
        uint256 price = bondingCurveProxy.getMintPrice();

        // Act
        vm.expectEmit();
        emit IUnitAuction.StartAuction(AUCTION_VARIANT_EXPANSION, uint32(block.timestamp), uint216(price));
        unitAuctionProxy.exposed_startExpansionAuction();

        // Assert
        (uint32 startTime, uint216 startPrice, uint8 variant) = unitAuctionProxy.auctionState();
        assertEq(startTime, block.timestamp);
        assertEq(startPrice, price);
        assertEq(variant, AUCTION_VARIANT_EXPANSION);
    }

    /**
     * ================ _terminateAuction() ================
     */

    function test_terminateAuction_SuccessfullyTerminates() public {
        // Arrnage & Act
        vm.expectEmit();
        emit IUnitAuction.TerminateAuction();
        unitAuctionProxy.exposed_terminateAuction();

        // Assert
        (uint32 startTime, uint216 startPrice, uint8 variant) = unitAuctionProxy.auctionState();
        assertEq(startTime, 0);
        assertEq(startPrice, 0);
        assertEq(variant, AUCTION_VARIANT_NONE);
    }

    /**
     * ================ inContractionRange() ================
     */

    function test_inContractionRange_SuccessfullyChecksRange() public {
        // Arrange
        uint256 rrOutOfContractionRangeLower = 1;
        uint256 rrOutOfContractionRangeHigher = 4;
        uint256 rrInContractionRange = 2;

        // Act & Assert
        assertEq(unitAuctionProxy.exposed_inContractionRange(rrOutOfContractionRangeLower), false);
        assertEq(unitAuctionProxy.exposed_inContractionRange(rrOutOfContractionRangeHigher), false);
        assertEq(unitAuctionProxy.exposed_inContractionRange(rrInContractionRange), true);
    }

    /**
     * ================ inExpansionRange() ================
     */

    function test_inExpansionRange_SuccessfullyChecksRange() public {
        // Arrange
        uint256 rrOutOfExpansionRange = 5;
        uint256 rrInExpansionRange = 6;

        // Act & Assert
        assertEq(unitAuctionProxy.exposed_inExpansionRange(rrOutOfExpansionRange), false);
        assertEq(unitAuctionProxy.exposed_inExpansionRange(rrInExpansionRange), true);
    }

    /**
     * ================ refreshState() ================
     */

    function test_refreshState_NoActiveAuction_ShouldNotStartNewAuction() public {
        // Arrange
        (uint32 startTimeBefore, uint216 startPriceBefore, uint8 variantBefore) = unitAuctionProxy.auctionState();
        assertEq(startTimeBefore, 0);
        assertEq(startPriceBefore, 0);
        assertEq(variantBefore, 1);

        // Act
        (, UnitAuction.AuctionState memory auctionState) = unitAuctionProxy.refreshState();

        // Assert
        assertEq(auctionState.startTime, 0);
        assertEq(auctionState.startPrice, 0);
        assertEq(auctionState.variant, 1);
    }

    function test_refreshState_Initial_StartsContractionAuction() public {
        // Arrange
        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.burn(3); // decreases RR

        // Act
        (uint256 reserveRatio, UnitAuction.AuctionState memory auctionState) = unitAuctionProxy.refreshState();

        // Assert
        uint256 mintPrice = bondingCurveProxy.getMintPrice();
        uint216 price = uint216(
            (mintPrice * unitAuctionProxy.startPriceBuffer()) / unitAuctionProxy.START_PRICE_BUFFER_PRECISION()
        );
        assertEq(reserveRatio, 2);
        assertEq(auctionState.startTime, block.timestamp);
        assertEq(auctionState.startPrice, price);
        assertEq(auctionState.variant, AUCTION_VARIANT_CONTRACTION);
    }

    function test_refreshState_Initial_StartsExpansionAuction() public {
        // Arrange
        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(1); // increases RR

        // Act
        (uint256 reserveRatio, UnitAuction.AuctionState memory auctionState) = unitAuctionProxy.refreshState();

        // Assert
        uint256 price = bondingCurveProxy.getMintPrice();
        assertEq(reserveRatio, 6);
        assertEq(auctionState.startTime, block.timestamp);
        assertEq(auctionState.startPrice, price);
        assertEq(auctionState.variant, AUCTION_VARIANT_EXPANSION);
    }

    function test_refreshState_AlreadyInContraction_RestartsContractionAuction() public {
        // Arrange
        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.burn(2); // increases RR

        // starts initial expansion auction
        (uint256 reserveRatioBefore, UnitAuction.AuctionState memory auctionStateBefore) = unitAuctionProxy
            .refreshState();
        uint256 mintPriceBefore = bondingCurveProxy.getMintPrice();
        uint216 priceBefore = uint216(
            (mintPriceBefore * unitAuctionProxy.startPriceBuffer()) / unitAuctionProxy.START_PRICE_BUFFER_PRECISION()
        );
        assertEq(reserveRatioBefore, 3);
        assertEq(auctionStateBefore.startTime, block.timestamp);
        assertEq(auctionStateBefore.startPrice, priceBefore);
        assertEq(auctionStateBefore.variant, AUCTION_VARIANT_CONTRACTION);
        // set up block timestamp as current + `contractionAuctionMaxDuration` + 1 seconds
        vm.warp(TestUtils.START_TIMESTAMP + unitAuctionProxy.contractionAuctionMaxDuration() + 1 seconds);

        uint256 mintPrice = bondingCurveProxy.getMintPrice();
        uint216 price = uint216(
            (mintPrice * unitAuctionProxy.startPriceBuffer()) / unitAuctionProxy.START_PRICE_BUFFER_PRECISION()
        );
        // Act
        (uint256 reserveRatio, UnitAuction.AuctionState memory auctionState) = unitAuctionProxy.refreshState();

        // Assert
        assertEq(reserveRatio, 2);
        assertEq(auctionState.startTime, block.timestamp);
        assertEq(auctionState.startPrice, price);
        assertEq(auctionState.variant, AUCTION_VARIANT_CONTRACTION);
    }

    function test_refreshState_AlreadyInContraction_StartsExpansionAuction() public {
        // Arrange
        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.burn(2); // decreases RR

        // starts initial contraction auction
        (uint256 reserveRatioBefore, UnitAuction.AuctionState memory auctionStateBefore) = unitAuctionProxy
            .refreshState();
        uint256 mintPrice = bondingCurveProxy.getMintPrice();
        uint216 priceBefore = uint216(
            (mintPrice * unitAuctionProxy.startPriceBuffer()) / unitAuctionProxy.START_PRICE_BUFFER_PRECISION()
        );
        assertEq(reserveRatioBefore, 3);
        assertEq(auctionStateBefore.startTime, block.timestamp);
        assertEq(auctionStateBefore.startPrice, priceBefore);
        assertEq(auctionStateBefore.variant, AUCTION_VARIANT_CONTRACTION);
        // set up block timestamp as current + 1 seconds
        vm.warp(TestUtils.START_TIMESTAMP + 1 seconds);

        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(4); // increases RR

        uint256 price = bondingCurveProxy.getMintPrice();

        // Act
        (uint256 reserveRatio, UnitAuction.AuctionState memory auctionState) = unitAuctionProxy.refreshState();

        // Assert
        assertEq(reserveRatio, 6);
        assertEq(auctionState.startTime, block.timestamp);
        assertEq(auctionState.startPrice, price);
        assertEq(auctionState.variant, AUCTION_VARIANT_EXPANSION);
    }

    function test_refreshState_AlreadyInContraction_TerminatesAuction() public {
        // Arrange
        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.burn(2); // creases RR

        // starts initial contraction auction
        (uint256 reserveRatioBefore, UnitAuction.AuctionState memory auctionStateBefore) = unitAuctionProxy
            .refreshState();
        uint256 mintPrice = bondingCurveProxy.getMintPrice();
        uint216 price = uint216(
            (mintPrice * unitAuctionProxy.startPriceBuffer()) / unitAuctionProxy.START_PRICE_BUFFER_PRECISION()
        );
        assertEq(reserveRatioBefore, 3);
        assertEq(auctionStateBefore.startTime, block.timestamp);
        assertEq(auctionStateBefore.startPrice, price);
        assertEq(auctionStateBefore.variant, AUCTION_VARIANT_CONTRACTION);
        // set up block timestamp as current + 1 seconds
        vm.warp(TestUtils.START_TIMESTAMP + 1 seconds);

        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(2); // increases RR

        // Act
        (uint256 reserveRatio, UnitAuction.AuctionState memory auctionState) = unitAuctionProxy.refreshState();

        // Assert
        assertEq(reserveRatio, 4);
        assertEq(auctionState.startTime, 0);
        assertEq(auctionState.startPrice, 0);
        assertEq(auctionState.variant, AUCTION_VARIANT_NONE);
    }

    function test_refreshState_AlreadyInExpansion_RestartsExpansionAuction() public {
        // Arrange
        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(2); // increases RR

        // starts initial contraction auction
        (uint256 reserveRatioBefore, UnitAuction.AuctionState memory auctionStateBefore) = unitAuctionProxy
            .refreshState();
        assertEq(reserveRatioBefore, 7);
        assertEq(auctionStateBefore.startTime, block.timestamp);
        assertEq(auctionStateBefore.startPrice, bondingCurveProxy.getMintPrice());
        assertEq(auctionStateBefore.variant, AUCTION_VARIANT_EXPANSION);
        // set up block timestamp as current + `expansionAuctionMaxDuration` + 1 seconds
        vm.warp(TestUtils.START_TIMESTAMP + unitAuctionProxy.expansionAuctionMaxDuration() + 1 seconds);

        uint256 price = bondingCurveProxy.getMintPrice();

        // Act
        (uint256 reserveRatio, UnitAuction.AuctionState memory auctionState) = unitAuctionProxy.refreshState();

        // Assert
        assertEq(reserveRatio, 6);
        assertEq(auctionState.startTime, block.timestamp);
        assertEq(auctionState.startPrice, price);
        assertEq(auctionState.variant, AUCTION_VARIANT_EXPANSION);
    }

    function test_refreshState_AlreadyInExpansion_StartsContractionAuction() public {
        // Arrange
        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(2); // increases RR

        // starts initial contraction auction
        (uint256 reserveRatioBefore, UnitAuction.AuctionState memory auctionStateBefore) = unitAuctionProxy
            .refreshState();
        assertEq(reserveRatioBefore, 7);
        assertEq(auctionStateBefore.startTime, block.timestamp);
        assertEq(auctionStateBefore.startPrice, bondingCurveProxy.getMintPrice());
        assertEq(auctionStateBefore.variant, AUCTION_VARIANT_EXPANSION);
        // set up block timestamp as current + 1 seconds
        vm.warp(TestUtils.START_TIMESTAMP + 1 seconds);

        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.burn(4); // decreases RR

        // Act
        (uint256 reserveRatio, UnitAuction.AuctionState memory auctionState) = unitAuctionProxy.refreshState();

        // Assert
        uint256 mintPrice = bondingCurveProxy.getMintPrice();
        uint216 price = uint216(
            (mintPrice * unitAuctionProxy.startPriceBuffer()) / unitAuctionProxy.START_PRICE_BUFFER_PRECISION()
        );
        assertEq(reserveRatio, 2);
        assertEq(auctionState.startTime, block.timestamp);
        assertEq(auctionState.startPrice, price);
        assertEq(auctionState.variant, AUCTION_VARIANT_CONTRACTION);
    }

    function test_refreshState_AlreadyInExpansion_TerminatesAuction() public {
        // Arrange
        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.mint(2); // increases RR

        // starts initial contraction auction
        (uint256 reserveRatioBefore, UnitAuction.AuctionState memory auctionStateBefore) = unitAuctionProxy
            .refreshState();
        assertEq(reserveRatioBefore, 7);
        assertEq(auctionStateBefore.startTime, block.timestamp);
        assertEq(auctionStateBefore.startPrice, bondingCurveProxy.getMintPrice());
        assertEq(auctionStateBefore.variant, AUCTION_VARIANT_EXPANSION);

        // set up block timestamp as current + 1 seconds
        vm.warp(TestUtils.START_TIMESTAMP + 1 seconds);

        vm.prank(address(bondingCurveProxy));
        collateralERC20Token.burn(2); // decreases RR

        // Act
        (uint256 reserveRatio, UnitAuction.AuctionState memory auctionState) = unitAuctionProxy.refreshState();

        // Assert
        assertEq(reserveRatio, 4);
        assertEq(auctionState.startTime, 0);
        assertEq(auctionState.startPrice, 0);
        assertEq(auctionState.variant, AUCTION_VARIANT_NONE);
    }
}
