// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import './IInflationOracle.sol';
import './ICollateralUsdOracle.sol';
import '../interfaces/IMineToken.sol';
import '../interfaces/IUnitToken.sol';
import '../interfaces/IERC20.sol';

interface IBondingCurve {
    /**
     * ================ ERRORS ================
     */

    /**
     * @dev Cannot mint due to too low reserve ratio.
     */
    error BondingCurveReserveRatioTooLow();

    /**
     * @dev Returned when the passed UNIT token does not have `expectedPrecision`.
     */
    error BondingCurveInvalidUnitTokenPrecision(uint256 invalidPrecision, uint256 expectedPrecision);

    /**
     * @dev Returned when the collateral/USD price oracle uses invalid precision.
     */
    error BondingCurveInvalidCollateralPricePrecision(uint256 invalidPrecision, uint256 expectedPrecision);

    /**
     * @dev Call unauthorized.
     */
    error BondingCurveForbidden();

    /**
     * ================ CONSTANTS ================
     */

    function STANDARD_PRECISION() external view returns (uint256);

    /**
     * ================ CORE FUNCTIONALITY ================
     */

    /**
     * @notice Initializes the proxy contract's.
     * Sets the values for {unitToken}, {mineToken}, {inflationOracle} and {collateralUsdOracle}.
     * @dev Calls Proxiable.initialize() at the end to set `initialized` flag.
     * @param _collateralToken Address of the token used as UNIT's stabilization collateral.
     * @param _unitToken UNIT token address.
     * @param _mineToken MINE token address.
     * @param _inflationOracle Inflation oracle.
     * @param _collateralUsdOracle Collateral Token-USD price oracle.
     */
    function initialize(
        IERC20 _collateralToken,
        IUnitToken _unitToken,
        IMineToken _mineToken,
        IInflationOracle _inflationOracle,
        ICollateralUsdOracle _collateralUsdOracle
    ) external;

    /**
     * @notice Transfers collateral token held by this contract to the `receiver`.
     * Used in UNIT contraction auction when collateral token is transferred to the user as a result of their bid.
     * @dev Can only be called by the UNIT auction contract.
     * @param receiver The address that will receive the collateral.
     * @param amount Collateral token amount to be transferred.
     */
    function transferCollateralToken(address receiver, uint256 amount) external;

    /**
     * @notice Creates UNIT token and assigns it to `receiver`. The amount created is proportional to the
     * `collateralAmountIn` and depends on the UNIT price expressed in collateral token and the spread.
     * Note that there is an edge case, where the caller passes a non-zero, albeit small, `collateralAmountIn`
     * and due to market conditions and rounding they may receive zero tokens in return.
     * @dev This function can only by called by UNIT token minter. See {UnitToken-mint}.
     * @param receiver The receiver of minted UNIT tokens.
     */
    function mint(address receiver, uint256 collateralAmountIn) external;

    /**
     * @notice Burns UNIT tokens and transfers a proportional amount of the collateral token to the caller. The returned amount
     * depends on the UNIT price expressed in collateral token and the spread.
     * Note that there is an edge case, where the caller passes a non-zero, albeit small, amount and due to market conditions
     * and rounding they may receive zero tokens in return.
     * @param unitTokenAmount UNIT token amount to be burned.
     */
    function burn(uint256 unitTokenAmount) external;

    /**
     * @notice Burns provided MINE token and redeems a portion of excess collateral token stored in the contract. The redeemed
     * amount is proportional to the burned MINE.
     * Note that there is an edge case, where the caller passes a non-zero, albeit small, amount and due to relatively large MINE
     * supply and rounding they may receive zero tokens in return.
     * @param mineTokenAmount MINE token amount to be burned.
     */
    function redeem(uint256 mineTokenAmount) external;

    /**
     * @dev Updates internal variables based on data from the inflation oracle. The function is expected to be called once a month.
     */
    function updateInternals() external;

    /**
     * ================ GETTERS ================
     */

    function collateralToken() external view returns (IERC20);

    /**
     * @notice Returns the current UNIT price used when minting UNIT. The price is expressed in collateral token.
     * @dev The returned value is in STANDARD_PRECISION.
     */
    function getMintPrice() external view returns (uint256);

    /**
     * @notice Returns the current UNIT price used when burning UNIT. The price is expressed in collateral token.
     * @dev The returned value is in STANDARD_PRECISION.
     */
    function getBurnPrice() external view returns (uint256);

    /**
     * @notice Returns the current UNIT price expressed in USD.
     * @dev The returned value is in STANDARD_PRECISION.
     */
    function getUnitUsdPrice() external view returns (uint256);

    /**
     * @notice Returns the current UNIT price expressed in collateral token.
     * @dev The returned value is in STANDARD_PRECISION.
     */
    function getUnitCollateralPrice() external view returns (uint256);

    /**
     * @notice Returns the current protocol reserve ratio.
     * @dev The returned value is in STANDARD_PRECISION.
     */
    function getReserveRatio() external view returns (uint256);

    /**
     * @notice Returns the current excess collateral amount in the reserve.
     * @dev The returned value is in collateral token precision.
     */
    function getExcessCollateralReserve() external view returns (uint256);

    /**
     * @notice Calculates the maximum amount of UNIT that can be burned to increase the reserve ratio to just below
     * {ProtocolConstants.HIGH_RR}. As UNIT is burned, an equivalent amount of collateral is removed from the reserve
     * based on the UNIT/collateral price {unitCollateralPrice}, which is accounted for in the result.
     * @param unitCollateralPrice UNIT price, expressed in collateral token, that is used in the calculation.
     * @return unitAmount The maximum amount of UNIT that can be successfully burned without causing the reserve ratio
     * to reach or exceed {ProtocolConstants.HIGH_RR}. The value is in UNIT token precision.
     */
    function quoteUnitBurnAmountForHighRR(uint256 unitCollateralPrice) external view returns (uint256 unitAmount);

    /**
     * @notice Calculates the maximum amount of collateral the protocol can accept to decrease the reserve ratio to
     * {ProtocolConstants.TARGET_RR}. As collateral reserve increases, an equivalent amount of UNIT is minted based on
     * the UNIT/collateral price {unitCollateralPrice}, which is accounted for in the result.
     * @param unitCollateralPrice UNIT price, expressed in collateral token, that is used in the calculation.
     * @return collateralAmount The maximum amount of collateral that can be successfully added to the reserve without
     * causing the reserve ratio to reach {ProtocolConstants.TARGET_RR}. The value is in collateral token precision.
     */
    function quoteCollateralAmountInForTargetRR(
        uint256 unitCollateralPrice
    ) external view returns (uint256 collateralAmount);
}
