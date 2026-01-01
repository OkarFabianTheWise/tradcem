// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IDEXRouter.sol";
import "./interfaces/IFeeCollector.sol";
import "./interfaces/IRebalanceValidator.sol";
import "./interfaces/IEmergencyModule.sol";

/**
 * @title TradCemFund
 * @dev Main fund contract implementing ERC20 shares with automated portfolio management
 */
contract TradCemFund is ERC20, ReentrancyGuard, Ownable, Pausable {
    // Structs
    struct Trade {
        address fromAsset;
        address toAsset;
        uint256 amountIn;
        uint256 minOut;
    }

    struct FundConfig {
        uint128 managementFee;      // Basis points (e.g., 200 = 2%)
        uint128 performanceFee;     // Basis points (e.g., 2000 = 20%)
        uint128 rebalanceInterval;  // Seconds between rebalances
        uint128 weightTolerance;    // Basis points tolerance for weights
        uint128 lastRebalance;      // Timestamp of last rebalance
        uint128 lastFeeCollection;  // Timestamp of last fee collection
    }

    // State variables
    address public manager;
    address[] public allowedAssets;
    mapping(address => uint256) public targetWeights; // Basis points
    mapping(address => bool) public isAllowedAsset;

    IPriceOracle public priceOracle;
    IDEXRouter public dexRouter;
    IFeeCollector public feeCollector;
    IRebalanceValidator public rebalanceValidator;
    IEmergencyModule public emergencyModule;

    FundConfig public config;
    uint256 public highWaterMark; // For performance fees
    bool public isEmergencyMode;

    // Events
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Redemption(address indexed user, uint256 shares, uint256 amount);
    event Rebalanced(Trade[] trades);
    event ManagementFeeCollected(uint256 shares, uint256 feeAmount);
    event PerformanceFeeCollected(uint256 shares, uint256 feeAmount);
    event EmergencyModeEnabled();
    event EmergencyModeDisabled();

    // Modifiers
    modifier onlyManager() {
        require(msg.sender == manager, "Not manager");
        _;
    }

    modifier whenNotEmergency() {
        require(!isEmergencyMode, "Emergency mode active");
        _;
    }

    /**
     * @dev Constructor
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address _manager,
        address[] memory _allowedAssets,
        uint256[] memory _targetWeights,
        address _priceOracle,
        address _dexRouter,
        address _feeCollector,
        address _rebalanceValidator,
        address _emergencyModule,
        uint256 _managementFee,
        uint256 _performanceFee,
        uint256 _rebalanceInterval,
        uint256 _weightTolerance
    ) ERC20(name_, symbol_) {
        require(_manager != address(0), "Invalid manager");
        require(_allowedAssets.length == _targetWeights.length, "Assets/weights mismatch");
        require(_allowedAssets.length > 0, "No assets");

        manager = _manager;
        allowedAssets = _allowedAssets;

        // Validate and set weights
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < _allowedAssets.length; i++) {
            require(_targetWeights[i] > 0, "Zero weight not allowed");
            totalWeight += _targetWeights[i];
            targetWeights[_allowedAssets[i]] = _targetWeights[i];
            isAllowedAsset[_allowedAssets[i]] = true;
        }
        require(totalWeight == 10000, "Weights must sum to 10000");

        priceOracle = IPriceOracle(_priceOracle);
        dexRouter = IDEXRouter(_dexRouter);
        feeCollector = IFeeCollector(_feeCollector);
        rebalanceValidator = IRebalanceValidator(_rebalanceValidator);
        emergencyModule = IEmergencyModule(_emergencyModule);

        config = FundConfig({
            managementFee: uint128(_managementFee),
            performanceFee: uint128(_performanceFee),
            rebalanceInterval: uint128(_rebalanceInterval),
            weightTolerance: uint128(_weightTolerance),
            lastRebalance: uint128(block.timestamp),
            lastFeeCollection: uint128(block.timestamp)
        });

        highWaterMark = 1e18; // Start at $1 per share
    }

    /**
     * @dev Deposit base asset and mint shares
     * @param amount Amount of base asset to deposit
     */
    function deposit(uint256 amount) external nonReentrant whenNotPaused whenNotEmergency {
        require(amount > 0, "Zero deposit");

        address baseAsset = allowedAssets[0]; // Assume first asset is base
        require(IERC20(baseAsset).transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Accrue fees before calculating NAV
        _accrueManagementFee();

        uint256 nav = calculateNAV();
        uint256 totalSupply = totalSupply();
        uint256 sharesToMint;

        if (totalSupply == 0) {
            // First deposit: 1:1 ratio
            sharesToMint = amount * 1e18 / _getPrice(baseAsset);
        } else {
            // Subsequent deposits: proportional to NAV
            sharesToMint = (amount * _getPrice(baseAsset) * totalSupply) / nav;
        }

        _mint(msg.sender, sharesToMint);

        // Allocate deposit proportionally
        _allocateDeposit(amount, baseAsset);

        emit Deposit(msg.sender, amount, sharesToMint);
    }

    /**
     * @dev Redeem shares for proportional assets
     * @param shares Amount of shares to redeem
     */
    function redeem(uint256 shares) external nonReentrant whenNotEmergency {
        require(shares > 0 && shares <= balanceOf(msg.sender), "Invalid amount");

        // Accrue fees before calculating NAV
        _accrueManagementFee();

        uint256 nav = calculateNAV();
        uint256 totalSupply = totalSupply();
        uint256 userNAV = (shares * nav) / totalSupply;

        _burn(msg.sender, shares);

        // Withdraw proportional assets
        _withdrawProportionalAssets(msg.sender, userNAV);

        emit Redemption(msg.sender, shares, userNAV);
    }

    /**
     * @dev Redeem shares to single asset
     * @param shares Amount of shares to redeem
     * @param outputAsset Asset to receive
     */
    function redeemToSingleAsset(uint256 shares, address outputAsset) external nonReentrant whenNotEmergency {
        require(shares > 0 && shares <= balanceOf(msg.sender), "Invalid amount");
        require(isAllowedAsset[outputAsset], "Asset not allowed");

        // Accrue fees before calculating NAV
        _accrueManagementFee();

        uint256 nav = calculateNAV();
        uint256 totalSupply = totalSupply();
        uint256 userNAV = (shares * nav) / totalSupply;

        _burn(msg.sender, shares);

        // Convert to single asset
        uint256 outputAmount = _convertToSingleAsset(userNAV, outputAsset);
        require(IERC20(outputAsset).transfer(msg.sender, outputAmount), "Transfer failed");

        emit Redemption(msg.sender, shares, outputAmount);
    }

    /**
     * @dev Rebalance portfolio (only manager)
     */
    function rebalance() external onlyManager whenNotPaused whenNotEmergency {
        require(canRebalance(), "Rebalance not allowed");

        // Accrue fees
        _accrueManagementFee();

        // Calculate required trades
        Trade[] memory trades = rebalanceValidator.calculateRequiredTrades(
            allowedAssets,
            _getCurrentWeights(),
            _getTargetWeightsArray(),
            config.weightTolerance
        );

        // Execute trades
        for (uint256 i = 0; i < trades.length; i++) {
            _executeTrade(trades[i]);
        }

        config.lastRebalance = uint128(block.timestamp);

        emit Rebalanced(trades);
    }

    /**
     * @dev Check if rebalance is needed
     */
    function canRebalance() public view returns (bool) {
        if (block.timestamp < config.lastRebalance + config.rebalanceInterval) {
            return false;
        }

        uint256[] memory currentWeights = _getCurrentWeights();
        uint256[] memory targetWeights = _getTargetWeightsArray();

        return rebalanceValidator.validateRebalance(
            allowedAssets,
            currentWeights,
            targetWeights,
            config.weightTolerance
        );
    }

    /**
     * @dev Calculate Net Asset Value
     */
    function calculateNAV() public view returns (uint256) {
        uint256 totalValue = 0;
        for (uint256 i = 0; i < allowedAssets.length; i++) {
            address asset = allowedAssets[i];
            uint256 balance = IERC20(asset).balanceOf(address(this));
            uint256 price = _getPrice(asset);
            totalValue += balance * price;
        }
        return totalValue;
    }

    /**
     * @dev Get share price
     */
    function getSharePrice() public view returns (uint256) {
        uint256 nav = calculateNAV();
        uint256 supply = totalSupply();
        if (supply == 0) return 1e18; // $1 per share initially
        return (nav * 1e18) / supply;
    }

    /**
     * @dev Enable emergency mode
     */
    function enableEmergencyMode() external {
        require(msg.sender == manager || emergencyModule.isEmergency(address(this)), "Not authorized");
        isEmergencyMode = true;
        _pause();
        emit EmergencyModeEnabled();
    }

    /**
     * @dev Disable emergency mode
     */
    function disableEmergencyMode() external onlyManager {
        isEmergencyMode = false;
        _unpause();
        emit EmergencyModeDisabled();
    }

    /**
     * @dev Emergency redeem (proportional withdrawal)
     */
    function emergencyRedeem(uint256 shares) external whenNotEmergency {
        require(isEmergencyMode, "Not in emergency");
        require(shares > 0 && shares <= balanceOf(msg.sender), "Invalid amount");

        uint256 totalSupply = totalSupply();
        _burn(msg.sender, shares);

        // Withdraw proportional assets without NAV calculation
        for (uint256 i = 0; i < allowedAssets.length; i++) {
            address asset = allowedAssets[i];
            uint256 balance = IERC20(asset).balanceOf(address(this));
            uint256 userShare = (shares * balance) / totalSupply;
            if (userShare > 0) {
                require(IERC20(asset).transfer(msg.sender, userShare), "Transfer failed");
            }
        }
    }

    // Internal functions

    function _getPrice(address asset) internal view returns (uint256) {
        (uint256 price, bool valid) = priceOracle.getPriceWithFallback(asset);
        require(valid, "Invalid price");
        return price;
    }

    function _allocateDeposit(uint256 amount, address baseAsset) internal {
        // For simplicity, allocate proportionally to target weights
        // In production, this might involve swapping
        uint256 nav = calculateNAV();
        if (nav == 0) return; // First deposit

        for (uint256 i = 0; i < allowedAssets.length; i++) {
            address asset = allowedAssets[i];
            if (asset == baseAsset) continue;

            uint256 targetAmount = (amount * targetWeights[asset]) / 10000;
            if (targetAmount > 0) {
                // Swap base asset to target asset
                dexRouter.swapWithSlippageProtection(
                    baseAsset,
                    asset,
                    targetAmount,
                    50 // 0.5% slippage
                );
            }
        }
    }

    function _withdrawProportionalAssets(address user, uint256 userNAV) internal {
        for (uint256 i = 0; i < allowedAssets.length; i++) {
            address asset = allowedAssets[i];
            uint256 assetValue = IERC20(asset).balanceOf(address(this)) * _getPrice(asset);
            uint256 userAssetValue = (userNAV * assetValue) / calculateNAV();
            uint256 userAssetAmount = userAssetValue / _getPrice(asset);

            if (userAssetAmount > 0) {
                require(IERC20(asset).transfer(user, userAssetAmount), "Transfer failed");
            }
        }
    }

    function _convertToSingleAsset(uint256 userNAV, address outputAsset) internal returns (uint256) {
        uint256 totalOutput = 0;

        for (uint256 i = 0; i < allowedAssets.length; i++) {
            address asset = allowedAssets[i];
            if (asset == outputAsset) {
                uint256 assetBalance = IERC20(asset).balanceOf(address(this));
                uint256 assetValue = assetBalance * _getPrice(asset);
                uint256 userAssetValue = (userNAV * assetValue) / calculateNAV();
                totalOutput += userAssetValue / _getPrice(asset);
            } else {
                uint256 assetBalance = IERC20(asset).balanceOf(address(this));
                uint256 assetValue = assetBalance * _getPrice(asset);
                uint256 userAssetAmount = (userNAV * assetValue) / calculateNAV() / _getPrice(asset);

                if (userAssetAmount > 0) {
                    totalOutput += dexRouter.swapWithSlippageProtection(
                        asset,
                        outputAsset,
                        userAssetAmount,
                        50 // 0.5% slippage
                    );
                }
            }
        }

        return totalOutput;
    }

    function _executeTrade(Trade memory trade) internal {
        require(isAllowedAsset[trade.fromAsset] && isAllowedAsset[trade.toAsset], "Invalid assets");

        uint256 amountOut = dexRouter.swapWithSlippageProtection(
            trade.fromAsset,
            trade.toAsset,
            trade.amountIn,
            50 // 0.5% slippage
        );

        require(amountOut >= trade.minOut, "Slippage exceeded");
    }

    function _getCurrentWeights() internal view returns (uint256[] memory) {
        uint256 nav = calculateNAV();
        uint256[] memory weights = new uint256[](allowedAssets.length);

        for (uint256 i = 0; i < allowedAssets.length; i++) {
            address asset = allowedAssets[i];
            uint256 balance = IERC20(asset).balanceOf(address(this));
            uint256 value = balance * _getPrice(asset);
            weights[i] = (value * 10000) / nav;
        }

        return weights;
    }

    function _getTargetWeightsArray() internal view returns (uint256[] memory) {
        uint256[] memory weights = new uint256[](allowedAssets.length);
        for (uint256 i = 0; i < allowedAssets.length; i++) {
            weights[i] = targetWeights[allowedAssets[i]];
        }
        return weights;
    }

    function _accrueManagementFee() internal {
        if (config.managementFee == 0) return;

        uint256 timeSinceLastCollection = block.timestamp - config.lastFeeCollection;
        if (timeSinceLastCollection == 0) return;

        uint256 totalSupply = totalSupply();
        if (totalSupply == 0) return;

        // Annual fee rate * time fraction
        uint256 feeRate = (config.managementFee * timeSinceLastCollection) / (365 days * 10000);
        uint256 sharesToMint = (totalSupply * feeRate) / (1e18 - feeRate);

        if (sharesToMint > 0) {
            _mint(address(feeCollector), sharesToMint);
            config.lastFeeCollection = uint128(block.timestamp);

            emit ManagementFeeCollected(sharesToMint, feeRate);
        }
    }

    function _collectPerformanceFee() internal {
        if (config.performanceFee == 0) return;

        uint256 currentPrice = getSharePrice();
        if (currentPrice <= highWaterMark) return;

        uint256 profit = currentPrice - highWaterMark;
        uint256 feeAmount = (profit * config.performanceFee) / 10000;
        uint256 newHighWaterMark = currentPrice - feeAmount;

        uint256 totalSupply = totalSupply();
        uint256 sharesToMint = (totalSupply * feeAmount) / (currentPrice - feeAmount);

        if (sharesToMint > 0) {
            _mint(address(feeCollector), sharesToMint);
            highWaterMark = newHighWaterMark;

            emit PerformanceFeeCollected(sharesToMint, feeAmount);
        }
    }
}