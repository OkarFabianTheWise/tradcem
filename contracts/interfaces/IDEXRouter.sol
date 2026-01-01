// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IDEXRouter
 * @dev Interface for DEX router with slippage protection
 */
interface IDEXRouter {
    /**
     * @dev Swap tokens with slippage protection
     * @param fromToken Token to swap from
     * @param toToken Token to swap to
     * @param amountIn Amount of fromToken to swap
     * @param maxSlippage Maximum slippage in basis points (e.g., 50 = 0.5%)
     * @return amountOut Amount of toToken received
     */
    function swapWithSlippageProtection(
        address fromToken,
        address toToken,
        uint256 amountIn,
        uint256 maxSlippage
    ) external returns (uint256 amountOut);

    /**
     * @dev Get best route for a swap
     * @param fromToken Token to swap from
     * @param toToken Token to swap to
     * @param amountIn Amount of fromToken
     * @return path Array of token addresses for the swap route
     */
    function getBestRoute(
        address fromToken,
        address toToken,
        uint256 amountIn
    ) external view returns (address[] memory path);
}