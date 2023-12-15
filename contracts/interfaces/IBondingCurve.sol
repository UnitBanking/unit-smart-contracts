// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './IInflationOracle.sol';
import './IEthUsdOracle.sol';
import '../MineToken.sol';
import '../UnitToken.sol';

interface IBondingCurve {
    /**
     * ================ ERRORS ================
     */

    /**
     * @dev Cannot mint due to too low reserve ratio.
     */
    error BondingCurveMintDisabled();

    /**
     * @dev Returned when the passed UNIT token does not have `expectedPrecision`.
     */
    error BondingCurveInvalidUnitTokenPrecision(uint256 invalidPrecision, uint256 expectedPrecision);

    /**
     * ================ CORE FUNCTIONALITY ================
     */

    /**
     * @notice Initializes the proxy contract's.
     * Sets the values for {unitToken}, {mineToken}, {inflationOracle} and {ethUsdOracle}.
     * @dev Calls Proxiable.initialize() at the end to set `initialized` flag.
     * @param _unitToken UNIT token address.
     * @param _mineToken MINE token address.
     * @param _inflationOracle Inflation oracle.
     * @param _ethUsdOracle ETH-USD price oracle.
     */
    function initialize(
        UnitToken _unitToken,
        MineToken _mineToken,
        IInflationOracle _inflationOracle,
        IEthUsdOracle _ethUsdOracle
    ) external;

    /**
     * @notice Creates UNIT token and assigns it to `receiver`. The amount created is proportional to the collateral token
     * amount passed and depends on the UNIT price expressed in collateral token and the spread.
     * Note that there is an edge case, where the caller passes a non-zero, albeit small, amount and due to market conditions
     * and rounding they may receive zero tokens in return.
     * @dev This function can only by called by UNIT token minter. See {UnitToken-mint}.
     * @param receiver The receiver of minted UNIT tokens.
     */
    function mint(address receiver) external payable;

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

    function getUnitUsdPrice() external view returns (uint256);

    function getUnitEthPrice() external view returns (uint256);

    function getReserveRatio() external view returns (uint256);

    function getExcessEthReserve() external view returns (uint256);
}
