// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IRebalanceValidator.sol";
import "./TradCemFund.sol";

/**
 * @title RebalanceValidator
 * @dev Validate rebalance operations and calculate required trades
 */
contract RebalanceValidator is IRebalanceValidator {
    uint256 public constant MAX_TRADE_IMPACT = 500; // 5% max trade impact

    /**
     * @dev Validate if rebalance is needed
     */
    function validateRebalance(
        address[] memory assets,
        uint256[] memory currentWeights,
        uint256[] memory targetWeights,
        uint256 tolerance
    ) external pure override returns (bool needsRebalance) {
        require(assets.length == currentWeights.length, "Assets/weights mismatch");
        require(assets.length == targetWeights.length, "Target weights mismatch");

        for (uint256 i = 0; i < assets.length; i++) {
            uint256 diff = currentWeights[i] > targetWeights[i]
                ? currentWeights[i] - targetWeights[i]
                : targetWeights[i] - currentWeights[i];

            if (diff > tolerance) {
                return true;
            }
        }

        return false;
    }

    /**
     * @dev Calculate required trades for rebalancing
     */
    function calculateRequiredTrades(
        address[] memory assets,
        uint256[] memory currentWeights,
        uint256[] memory targetWeights,
        uint256 tolerance
    ) external pure override returns (TradCemFund.Trade[] memory trades) {
        require(assets.length == currentWeights.length, "Assets/weights mismatch");
        require(assets.length == targetWeights.length, "Target weights mismatch");

        // Calculate total NAV (simplified - assume weights are in basis points)
        uint256 totalCurrentWeight = 0;
        uint256 totalTargetWeight = 0;

        for (uint256 i = 0; i < currentWeights.length; i++) {
            totalCurrentWeight += currentWeights[i];
            totalTargetWeight += targetWeights[i];
        }

        require(totalCurrentWeight == 10000, "Current weights don't sum to 10000");
        require(totalTargetWeight == 10000, "Target weights don't sum to 10000");

        // Calculate trades needed
        // This is a simplified version. In production, use more sophisticated algorithms
        uint256 tradeCount = 0;
        TradCemFund.Trade[] memory tempTrades = new TradCemFund.Trade[](assets.length * 2);

        for (uint256 i = 0; i < assets.length; i++) {
            if (currentWeights[i] > targetWeights[i] + tolerance) {
                // Need to sell this asset
                uint256 excessWeight = currentWeights[i] - targetWeights[i];
                // Find asset to buy
                for (uint256 j = 0; j < assets.length; j++) {
                    if (currentWeights[j] < targetWeights[j] - tolerance) {
                        // Calculate trade amount
                        uint256 deficitWeight = targetWeights[j] - currentWeights[j];
                        uint256 tradeWeight = excessWeight < deficitWeight ? excessWeight : deficitWeight;

                        // Create trade: sell i, buy j
                        tempTrades[tradeCount] = TradCemFund.Trade({
                            fromAsset: assets[i],
                            toAsset: assets[j],
                            amountIn: 0, // To be calculated based on NAV
                            minOut: 0   // To be calculated
                        });
                        tradeCount++;

                        // Update weights (simplified)
                        currentWeights[i] -= tradeWeight;
                        currentWeights[j] += tradeWeight;

                        if (excessWeight <= deficitWeight) break;
                    }
                }
            }
        }

        // Resize array
        trades = new TradCemFund.Trade[](tradeCount);
        for (uint256 i = 0; i < tradeCount; i++) {
            trades[i] = tempTrades[i];
        }

        return trades;
    }

    /**
     * @dev Calculate trade amounts based on NAV
     */
    function calculateTradeAmounts(
        TradCemFund.Trade[] memory trades,
        uint256 totalNAV,
        uint256[] memory currentBalances
    ) external pure returns (TradCemFund.Trade[] memory) {
        // Calculate actual amounts based on current balances and NAV
        for (uint256 i = 0; i < trades.length; i++) {
            // This is a placeholder - actual implementation would calculate
            // amounts based on portfolio value and desired weight changes
            trades[i].amountIn = totalNAV / 100; // 1% of NAV as example
            trades[i].minOut = (trades[i].amountIn * 95) / 100; // 5% slippage
        }

        return trades;
    }
}