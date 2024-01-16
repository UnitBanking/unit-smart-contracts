// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import { UnitAuctionTestBase } from './UnitAuctionTestBase.t.sol';
import { TestUtils } from '../utils/TestUtils.t.sol';
import { Ownable } from '../../../contracts/abstracts/Ownable.sol';

contract UnitAuctionTest is UnitAuctionTestBase {
    function test_constructor_stateVariablesSetCorrectly() public {
        // Arrange & Act & Assert
        assertEq(unitAuctionImplementation.initialized(), true);
        assertEq(address(unitAuctionProxy.bondingCurve()), address(bondingCurve));
        assertEq(address(unitAuctionProxy.unitToken()), address(unitToken));
    }

    function test_receive_NoDirectTransfer() public {
        // Arrange
        address user = _createUserAndMintUnitToken(1e18);
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
        address user = _createUserAndMintUnitToken(1e18);
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
        address user = _createUserAndMintUnitToken(1e18);
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
        address user = _createUserAndMintUnitToken(1e18);
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
        uint256 mintPrice = bondingCurve.getMintPrice();
        uint216 price = uint216(
            (mintPrice * unitAuctionProxy.startPriceBuffer()) / unitAuctionProxy.START_PRICE_BUFFER_PRECISION()
        );

        // Act
        unitAuctionProxy.exposed_startContractionAuction();

        // Assert
        (uint32 startTime, uint216 startPrice, uint8 variant) = unitAuctionProxy.auctionState();
        assertEq(startTime, block.timestamp);
        assertEq(startPrice, price);
        assertEq(variant, 2);
    }

    /**
     * ================ _startExpansionAuction() ================
     */

    function test_startExpansionAuction_SuccessfullyStarts() public {
        // Arrnage
        uint256 price = bondingCurve.getMintPrice();

        // Act
        unitAuctionProxy.exposed_startExpansionAuction();

        // Assert
        (uint32 startTime, uint216 startPrice, uint8 variant) = unitAuctionProxy.auctionState();
        assertEq(startTime, block.timestamp);
        assertEq(startPrice, price);
        assertEq(variant, 3);
    }

    /**
     * ================ _terminateAuction() ================
     */

    function test_terminateAuction_SuccessfullyTerminates() public {
        // Arrnage & Act
        unitAuctionProxy.exposed_terminateAuction();

        // Assert
        (uint32 startTime, uint216 startPrice, uint8 variant) = unitAuctionProxy.auctionState();
        assertEq(startTime, 0);
        assertEq(startPrice, 0);
        assertEq(variant, 1);
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
}
