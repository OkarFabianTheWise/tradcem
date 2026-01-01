// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol"; // Commented out for testnet
import "./interfaces/IPriceOracle.sol";

/**
 * @title PriceOracle
 * @dev Aggregates price feeds from multiple sources with fallback support
 */
contract PriceOracle is IPriceOracle, Ownable {
    struct PriceFeed {
        address chainlinkFeed;
        address binanceFeed; // Placeholder for Binance Oracle
        address pythFeed;    // Placeholder for Pyth
        uint256 heartbeat;   // Maximum age of price in seconds
        bool active;
    }

    mapping(address => PriceFeed) public priceFeeds;
    address[] public supportedAssets;

    uint256 public constant MAX_PRICE_AGE = 3600; // 1 hour
    uint256 public constant GRACE_PERIOD = 300;   // 5 minutes grace period

    event PriceFeedUpdated(address indexed asset, address chainlinkFeed, address binanceFeed, address pythFeed);
    event AssetAdded(address indexed asset);
    event AssetRemoved(address indexed asset);

    /**
     * @dev Get price for an asset
     */
    function getPrice(address asset) external view override returns (uint256) {
        (uint256 price, bool valid) = getPriceWithFallback(asset);
        require(valid, "Price not available");
        return price;
    }

    /**
     * @dev Get price with fallback validation
     */
    function getPriceWithFallback(address asset) public view override returns (uint256 price, bool valid) {
        PriceFeed memory feed = priceFeeds[asset];
        require(feed.active, "Asset not supported");

        // Try Chainlink first
        (uint256 chainlinkPrice, bool chainlinkValid) = _getChainlinkPrice(feed.chainlinkFeed);
        if (chainlinkValid) {
            return (chainlinkPrice, true);
        }

        // Try Binance Oracle
        (uint256 binancePrice, bool binanceValid) = _getBinancePrice(feed.binanceFeed);
        if (binanceValid) {
            return (binancePrice, true);
        }

        // Try Pyth
        (uint256 pythPrice, bool pythValid) = _getPythPrice(feed.pythFeed);
        if (pythValid) {
            return (pythPrice, true);
        }

        // If all fail, check if we're within grace period of last valid price
        // For simplicity, return invalid for now
        return (0, false);
    }

    /**
     * @dev Update price feed for an asset (interface implementation)
     */
    function updatePriceFeed(address asset, address feed) external override onlyOwner {
        require(priceFeeds[asset].active, "Asset not supported");
        priceFeeds[asset].chainlinkFeed = feed;
        emit PriceFeedUpdated(asset, feed, priceFeeds[asset].binanceFeed, priceFeeds[asset].pythFeed);
    }

    /**
     * @dev Add support for a new asset
     */
    function addAsset(
        address asset,
        address chainlinkFeed,
        address binanceFeed,
        address pythFeed
    ) external onlyOwner {
        require(asset != address(0), "Invalid asset");
        require(!priceFeeds[asset].active, "Asset already supported");

        priceFeeds[asset] = PriceFeed({
            chainlinkFeed: chainlinkFeed,
            binanceFeed: binanceFeed,
            pythFeed: pythFeed,
            heartbeat: MAX_PRICE_AGE,
            active: true
        });
        supportedAssets.push(asset);

        emit AssetAdded(asset);
    }

    /**
     * @dev Update all price feeds for an asset
     */
    function updatePriceFeeds(
        address asset,
        address chainlinkFeed,
        address binanceFeed,
        address pythFeed,
        uint256 heartbeat
    ) external onlyOwner {
        require(asset != address(0), "Invalid asset");

        if (!priceFeeds[asset].active) {
            supportedAssets.push(asset);
        }

        priceFeeds[asset] = PriceFeed({
            chainlinkFeed: chainlinkFeed,
            binanceFeed: binanceFeed,
            pythFeed: pythFeed,
            heartbeat: heartbeat == 0 ? MAX_PRICE_AGE : heartbeat,
            active: true
        });

        emit PriceFeedUpdated(asset, chainlinkFeed, binanceFeed, pythFeed);
    }

    /**
     * @dev Remove support for an asset
     */
    function removeAsset(address asset) external onlyOwner {
        require(priceFeeds[asset].active, "Asset not supported");

        priceFeeds[asset].active = false;

        // Remove from supportedAssets array
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            if (supportedAssets[i] == asset) {
                supportedAssets[i] = supportedAssets[supportedAssets.length - 1];
                supportedAssets.pop();
                break;
            }
        }

        emit AssetRemoved(asset);
    }

    /**
     * @dev Get number of supported assets
     */
    function getSupportedAssetsCount() external view returns (uint256) {
        return supportedAssets.length;
    }

    /**
     * @dev Get Chainlink price (simplified for testnet)
     */
    function _getChainlinkPrice(address feed) internal view returns (uint256 price, bool valid) {
        if (feed == address(0)) return (0, false);

        // For testnet, return mock prices
        // BUSD: $1.00
        // WBNB: $300.00
        // CAKE: $15.00

        if (feed == address(1)) { // Mock BUSD feed
            return (1e18, true); // $1.00
        } else if (feed == address(2)) { // Mock WBNB feed
            return (300e18, true); // $300.00
        } else if (feed == address(3)) { // Mock CAKE feed
            return (15e18, true); // $15.00
        }

        return (0, false);
    }

    /**
     * @dev Get Binance Oracle price (placeholder)
     */
    function _getBinancePrice(address feed) internal view returns (uint256 price, bool valid) {
        // Placeholder implementation
        // In production, integrate with Binance Oracle
        return (0, false);
    }

    /**
     * @dev Get Pyth price (placeholder)
     */
    function _getPythPrice(address feed) internal view returns (uint256 price, bool valid) {
        // Placeholder implementation
        // In production, integrate with Pyth Network
        return (0, false);
    }
}