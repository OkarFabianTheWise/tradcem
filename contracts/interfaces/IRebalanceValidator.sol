// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../TradCemFund.sol";

/**
 * @title IRebalanceValidator
 * @dev Interface for rebalance validation logic
 */
interface IRebalanceValidator {
    /**
     * @dev Validate if rebalance is needed
     * @param assets Array of asset addresses
     * @param currentWeights Current weight distribution
     * @param targetWeights Target weight distribution
     * @param tolerance Weight tolerance in basis points
     * @return needsRebalance Whether rebalance is needed
     */
    function validateRebalance(
        address[] memory assets,
        uint256[] memory currentWeights,
        uint256[] memory targetWeights,
        uint256 tolerance
    ) external pure returns (bool needsRebalance);

    /**
     * @dev Calculate required trades for rebalancing
     * @param assets Array of asset addresses
     * @param currentWeights Current weight distribution
     * @param targetWeights Target weight distribution
     * @param tolerance Weight tolerance in basis points
     * @return trades Array of Trade structs
     */
    function calculateRequiredTrades(
        address[] memory assets,
        uint256[] memory currentWeights,
        uint256[] memory targetWeights,
        uint256 tolerance
    ) external pure returns (TradCemFund.Trade[] memory trades);
}