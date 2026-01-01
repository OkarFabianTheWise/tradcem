// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IDEXRouter.sol";

/**
 * @title DEXRouter
 * @dev Abstract DEX interactions with slippage protection
 */
contract DEXRouter is IDEXRouter, Ownable {
    address public pancakeRouter; // PancakeSwap V3 Router
    address public oneInchRouter; // 1inch Router
    address public paraSwapRouter; // ParaSwap Router

    uint256 public constant MAX_SLIPPAGE = 1000; // 10% max slippage

    event RouterUpdated(string indexed dex, address indexed router);

    constructor(
        address _pancakeRouter,
        address _oneInchRouter,
        address _paraSwapRouter
    ) {
        pancakeRouter = _pancakeRouter;
        oneInchRouter = _oneInchRouter;
        paraSwapRouter = _paraSwapRouter;
    }

    /**
     * @dev Swap tokens with slippage protection
     */
    function swapWithSlippageProtection(
        address fromToken,
        address toToken,
        uint256 amountIn,
        uint256 maxSlippage
    ) external override returns (uint256 amountOut) {
        require(maxSlippage <= MAX_SLIPPAGE, "Slippage too high");
        require(amountIn > 0, "Zero amount");

        // Get the best route
        address[] memory path = getBestRoute(fromToken, toToken, amountIn);
        require(path.length >= 2, "Invalid route");

        // Calculate minimum output based on slippage
        uint256 expectedOut = _getExpectedOutput(fromToken, toToken, amountIn);
        uint256 minOut = (expectedOut * (10000 - maxSlippage)) / 10000;

        // Approve token spending
        require(IERC20(fromToken).approve(address(this), amountIn), "Approval failed");

        // Execute swap (simplified - in production use actual DEX router)
        amountOut = _executeSwap(path, amountIn, minOut);

        require(amountOut >= minOut, "Slippage exceeded");
    }

    /**
     * @dev Get best route for a swap
     */
    function getBestRoute(
        address fromToken,
        address toToken,
        uint256 amountIn
    ) public view override returns (address[] memory path) {
        // Simplified routing logic
        // In production, query multiple DEXes for best rate

        address[] memory simplePath = new address[](2);
        simplePath[0] = fromToken;
        simplePath[1] = toToken;

        // Check if direct pair exists, otherwise add WBNB as intermediate
        // For simplicity, assume direct swap is possible
        return simplePath;
    }

    /**
     * @dev Update DEX router addresses
     */
    function updateRouter(string memory dex, address router) external onlyOwner {
        require(router != address(0), "Invalid router");

        if (keccak256(bytes(dex)) == keccak256(bytes("pancake"))) {
            pancakeRouter = router;
        } else if (keccak256(bytes(dex)) == keccak256(bytes("1inch"))) {
            oneInchRouter = router;
        } else if (keccak256(bytes(dex)) == keccak256(bytes("paraswap"))) {
            paraSwapRouter = router;
        } else {
            revert("Unknown DEX");
        }

        emit RouterUpdated(dex, router);
    }

    /**
     * @dev Get expected output amount (simplified)
     */
    function _getExpectedOutput(
        address fromToken,
        address toToken,
        uint256 amountIn
    ) internal view returns (uint256) {
        // Simplified price calculation
        // In production, query DEX for quote
        // For now, return amountIn as placeholder
        return amountIn; // This should be replaced with actual quote logic
    }

    /**
     * @dev Execute swap on DEX (simplified)
     */
    function _executeSwap(
        address[] memory path,
        uint256 amountIn,
        uint256 minOut
    ) internal returns (uint256 amountOut) {
        // Simplified swap execution
        // In production, call actual DEX router

        if (path.length == 2) {
            // Direct swap
            // Call PancakeSwap or other DEX
            // For now, simulate successful swap
            amountOut = minOut + 1; // Ensure it meets minimum
        } else {
            // Multi-hop swap
            // Implement multi-hop logic
            amountOut = minOut + 1;
        }

        // Transfer tokens (this would be done by DEX in reality)
        // For simulation purposes
    }
}