// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IPriceOracle
 * @dev Interface for price oracle with fallback support
 */
interface IPriceOracle {
    /**
     * @dev Get price for an asset
     * @param asset Asset address
     * @return Price in USD with 18 decimals
     */
    function getPrice(address asset) external view returns (uint256);

    /**
     * @dev Get price with fallback validation
     * @param asset Asset address
     * @return price Price in USD with 18 decimals
     * @return valid Whether the price is valid
     */
    function getPriceWithFallback(address asset) external view returns (uint256 price, bool valid);

    /**
     * @dev Update price feed for an asset
     * @param asset Asset address
     * @param feed New price feed address
     */
    function updatePriceFeed(address asset, address feed) external;
}