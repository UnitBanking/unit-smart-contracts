// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import '../TestBase.t.sol';

import { UnitAuctionHarness } from '../../../contracts/test/UnitAuctionHarness.sol';
import { BondingCurve } from '../../../contracts/BondingCurve.sol';

abstract contract UnitAuctionTestBase is TestBase {
    address public bondingCurve; // In the tests it's mostly used as an address rather than a contract type

    UnitAuctionHarness public unitAuctionImplementation;
    UnitAuctionHarness public unitAuctionProxy;

    function setUp() public virtual {
        _setUp(18); // By default we set up an 18 decimal collateral token
    }

    function _setUp(uint8 collateralDecimals) internal {
        (, bondingCurve) = _setUp(BondingCurveType.Production, collateralDecimals);
        _setUpUnitAuction();
    }

    /**
     * @dev Must be called after {bondingCurve} has been initialized.
     */
    function _setUpUnitAuction() internal {
        unitAuctionImplementation = new UnitAuctionHarness(BondingCurve(bondingCurve), unitToken);
        Proxy proxy = new Proxy(address(this));
        proxy.upgradeToAndCall(
            address(unitAuctionImplementation),
            abi.encodeWithSelector(Proxiable.initialize.selector)
        );
        unitAuctionProxy = UnitAuctionHarness(payable(proxy));

        unitToken.setMinter(address(unitAuctionProxy), true);
        unitToken.setBurner(address(unitAuctionProxy), true);

        BondingCurve(bondingCurve).setUnitAuction(address(unitAuctionProxy));
    }

    function _createUserAndMintUnitAndCollateralToken(uint256 collateralAmount) internal returns (address user) {
        // create user
        user = vm.addr(2);

        // mint collateral token and approve contracts
        uint256 userCollateralBalance = 100 * 1e18;
        vm.startPrank(user);
        collateralToken.mint(userCollateralBalance);
        collateralToken.approve(bondingCurve, userCollateralBalance);
        collateralToken.approve(address(unitAuctionProxy), userCollateralBalance);
        vm.stopPrank();

        vm.warp(TestUtils.START_TIMESTAMP + 10 days);

        // mint unit token
        vm.prank(user);
        BondingCurve(bondingCurve).mint(user, collateralAmount);
    }

    function _createUserWithPrivateKeyAndMintUnitAndCollateralTokens(
        uint256 privateKey,
        uint256 collateralAmountIn
    ) internal returns (address user) {
        // create user
        user = vm.addr(privateKey);

        // mint collateral token and approve contracts
        uint256 userCollateralBalance = 500 * 1e18;
        vm.startPrank(user);
        collateralToken.mint(userCollateralBalance);
        collateralToken.approve(bondingCurve, userCollateralBalance);
        collateralToken.approve(address(unitAuctionProxy), userCollateralBalance);
        unitToken.approve(bondingCurve, collateralAmountIn);
        unitToken.approve(address(unitAuctionProxy), collateralAmountIn);
        vm.stopPrank();

        vm.warp(TestUtils.START_TIMESTAMP + 10 days);

        // mint unit token
        vm.prank(user);
        BondingCurve(bondingCurve).mint(user, collateralAmountIn);
    }
}
