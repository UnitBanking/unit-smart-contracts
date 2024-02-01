// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import './IInflationOracle.sol';
import './ICollateralUsdOracle.sol';
import '../MineToken.sol';
import '../UnitToken.sol';

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
     * @dev Call unauthorized.
     */
    error BondingCurveForbidden();

    /**
     * ================ CONSTANTS ================
     */

    function UNITUSD_PRICE_PRECISION() external pure returns (uint256);

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
        UnitToken _unitToken,
        MineToken _mineToken,
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
     * @dev Updates the values for {lastUnitUsdPrice}, {lastOracleInflationRate}, and {lastOracleUpdateTimestamp}.
     */
    function updateInternals() external;

    /**
     * ================ GETTERS ================
     */

    function collateralToken() external view returns (IERC20);

    /**
     * @notice Returns the current UNIT price, in collateral token, used when minting UNIT.
     */
    function getMintPrice() external view returns (uint256);

    /**
     * @notice Returns the current UNIT price, in collateral token, used when burning UNIT.
     */
    function getBurnPrice() external view returns (uint256);

    function getUnitUsdPrice() external view returns (uint256);

    function getUnitCollateralPrice() external view returns (uint256);

    function getReserveRatio() external view returns (uint256);

    function getExcessCollateralReserve() external view returns (uint256);
}
