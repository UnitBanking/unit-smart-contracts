// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import './IInflationOracle.sol';
import './IEthUsdOracle.sol';

interface IBondingCurve {
    /**
     * ================ ERRORS ================
     */

    /**
     * @dev The amount of tokens the user gets is zero.
     */
    error BondingCurveResultingTokenAmountZero();

    /**
     * @dev Cannot mint due to too low reserve ratio.
     */
    error BondingCurveMintDisabledDueToTooLowRR();

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
        address _unitToken,
        address _mineToken,
        IInflationOracle _inflationOracle,
        IEthUsdOracle _ethUsdOracle
    ) external;

    /**
     * @notice Allows to mint UNIT token to the specified receiver by providing ETH.
     * @dev This function can only by called by UNIT token minter. See {UnitToken-mint}.
     * @param receiver The receiver of minted UNIT tokens.
     */
    function mint(address receiver) external payable;

    /**
     * @notice Allows to redeem ETH by burning UNIT token.
     * @param unitTokenAmount UNIT token amount to be burned.
     */
    function burn(uint256 unitTokenAmount) external;

    /**
     * @notice Allows to redeem a portion of excess ETH by burning MINE token.
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
