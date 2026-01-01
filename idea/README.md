# TRADCEM ON-CHAIN FUND — EVM IMPLEMENTATION SPEC

## Aim (What the smart contracts exist to do)

The TradCem fund system exists to:

> **Represent a creator-managed portfolio as an on-chain, rules-enforced fund that investors can enter and exit at any time, with transparent accounting and no custody risk.**

More concretely, it aims to:

* Turn a portfolio strategy into a **verifiable financial object**
* Enforce strategy rules **without trusting the manager**
* Mint and burn fund shares fairly using ERC-20 standard
* Track performance and NAV on-chain
* Distribute fees automatically and transparently
* Leverage BNB Chain's low gas costs for frequent operations

This is **not** a trading bot.
It is **portfolio infrastructure**.

---

## Core Design Principles

1. **Non-custodial**

   * Users always hold ERC-20 fund tokens
   * No off-chain control over funds
   * Manager has zero withdrawal privileges

2. **Rules over discretion**

   * Managers define constraints upfront
   * All operations validated against immutable rules
   * Constraint violations revert transactions

3. **NAV-based accounting**

   * Investors buy shares, not trades
   * Price = NAV / total shares
   * Oracle-driven pricing

4. **Composable**

   * ERC-20 fund tokens work with any DeFi protocol
   * Integrates with PancakeSwap, Venus, etc.

---

## High-Level Architecture

### 1. FundFactory.sol

**Responsibility**: Deploy new funds

```solidity
contract FundFactory {
    mapping(address => address[]) public managerFunds;
    address[] public allFunds;
    
    function createFund(
        string memory name,
        string memory symbol,
        FundConfig memory config
    ) external returns (address fundAddress);
}
```

**Key features**:

* Deploys new TradCemFund contracts via `CREATE2`
* Deterministic addresses
* Registry of all funds
* Emits creation events for indexing

---

### 2. TradCemFund.sol (Core Contract)

**The main fund contract**. One deployment per fund.

**State Variables**:

```solidity
contract TradCemFund is ERC20, ReentrancyGuard {
    // Governance
    address public immutable manager;
    address public immutable factory;
    
    // Assets
    address[] public allowedAssets;
    mapping(address => bool) public isAllowedAsset;
    mapping(address => uint256) public targetWeights; // basis points (10000 = 100%)
    
    // Constraints
    uint256 public immutable maxLeverage; // 10000 = 1x
    uint256 public immutable rebalanceInterval; // seconds
    uint256 public lastRebalance;
    uint256 public immutable maxSlippage; // basis points
    uint256 public immutable weightTolerance; // basis points
    
    // Fees
    uint256 public immutable managementFee; // annual, basis points
    uint256 public immutable performanceFee; // basis points
    uint256 public highWaterMark; // NAV per share
    uint256 public lastFeeCollection;
    
    // Oracles
    address public immutable priceOracle;
    
    // Emergency
    bool public isPaused;
    bool public isEmergencyMode;
}
```

---

### 3. Asset Vaults (Internal Balances)

**No separate vault contracts needed** — BNB Chain's EVM model differs from Solana's account model.

Instead:

* Fund contract holds all ERC-20 tokens directly
* Balances tracked via ERC-20 standard: `IERC20(asset).balanceOf(address(this))`
* Withdrawal protection via access control modifiers

```solidity
// Assets held directly by contract
function getAssetBalance(address asset) public view returns (uint256) {
    return IERC20(asset).balanceOf(address(this));
}
```

This is **simpler than Solana's multi-account model**.

---

### 4. Fund Tokens (ERC-20 Shares)

Standard ERC-20 implementation with:

* Minted on deposit
* Burned on redemption
* Transferable (enables secondary markets)

```solidity
// Inherits OpenZeppelin ERC20
constructor(
    string memory name,
    string memory symbol
) ERC20(name, symbol) {
    // Fund tokens are 18 decimals by default
}
```

**Share price calculation**:

```solidity
function getSharePrice() public view returns (uint256) {
    uint256 nav = calculateNAV();
    uint256 supply = totalSupply();
    if (supply == 0) return 1e18; // Initial price: 1.0
    return (nav * 1e18) / supply;
}
```

---

## Fund Lifecycle (Step-by-Step)

### 1. Fund Creation

**Via FundFactory**:

```solidity
function createFund(
    string memory name,
    string memory symbol,
    address[] memory _allowedAssets,
    uint256[] memory _targetWeights,
    uint256 _maxLeverage,
    uint256 _rebalanceInterval,
    uint256 _managementFee,
    uint256 _performanceFee,
    address _priceOracle
) external returns (address) {
    
    // Validation
    require(_allowedAssets.length == _targetWeights.length);
    require(sumWeights(_targetWeights) == 10000); // 100%
    require(_managementFee <= 500); // Max 5% annual
    require(_performanceFee <= 2000); // Max 20%
    
    // Deploy fund contract
    TradCemFund fund = new TradCemFund{salt: keccak256(...)}(
        name,
        symbol,
        msg.sender, // manager
        FundConfig({...})
    );
    
    // Register
    managerFunds[msg.sender].push(address(fund));
    allFunds.push(address(fund));
    
    emit FundCreated(address(fund), msg.sender, name);
    return address(fund);
}
```

**Immutable parameters** stored in contract bytecode or immutable storage.

---

### 2. Deposits (Minting Shares)

**User flow**:

1. User approves base asset (e.g., USDC)
2. Calls `deposit(uint256 amount)`

**Contract logic**:

```solidity
function deposit(uint256 amount) external nonReentrant whenNotPaused {
    require(amount > 0, "Zero deposit");
    
    // Pull base asset from user
    IERC20(baseAsset).transferFrom(msg.sender, address(this), amount);
    
    // Calculate NAV and share price
    uint256 nav = calculateNAV();
    uint256 sharePrice = getSharePrice();
    uint256 sharesToMint = (amount * 1e18) / sharePrice;
    
    // Mint fund tokens
    _mint(msg.sender, sharesToMint);
    
    // Allocate assets according to target weights
    _allocateDeposit(amount);
    
    emit Deposit(msg.sender, amount, sharesToMint);
}
```

**Asset allocation**:

```solidity
function _allocateDeposit(uint256 amount) internal {
    for (uint i = 0; i < allowedAssets.length; i++) {
        address asset = allowedAssets[i];
        uint256 weight = targetWeights[asset];
        uint256 allocAmount = (amount * weight) / 10000;
        
        // Swap base asset -> target asset via DEX
        if (asset != baseAsset) {
            _swapOnDEX(baseAsset, asset, allocAmount);
        }
    }
}
```

**No slippage games. No preferential fills.**

---

### 3. Rebalancing Logic

**Trigger conditions**:

* Time-based: `block.timestamp >= lastRebalance + rebalanceInterval`
* Drift-based: Any asset weight exceeds `targetWeight ± weightTolerance`

**Permissioned execution**:

```solidity
modifier onlyManager() {
    require(msg.sender == manager, "Not manager");
    _;
}

function rebalance() external onlyManager whenNotPaused {
    require(canRebalance(), "Rebalance not allowed");
    
    // Get current weights
    uint256 nav = calculateNAV();
    uint256[] memory currentWeights = _calculateCurrentWeights(nav);
    
    // Calculate required trades
    Trade[] memory trades = _calculateRebalanceTrades(currentWeights);
    
    // Execute trades
    for (uint i = 0; i < trades.length; i++) {
        _executeTrade(trades[i]);
    }
    
    // Verify final state
    require(_validateAllocation(), "Post-rebalance validation failed");
    
    lastRebalance = block.timestamp;
    emit Rebalanced(trades);
}
```

**Constraint enforcement**:

```solidity
function _executeTrade(Trade memory trade) internal {
    // Slippage protection
    uint256 minOut = _calculateMinOut(trade.amountIn, trade.fromAsset, trade.toAsset);
    
    // Execute swap via approved DEX router
    uint256 amountOut = IRouter(dexRouter).swapExactTokensForTokens(
        trade.amountIn,
        minOut,
        trade.path,
        address(this),
        block.timestamp + 300
    )[trade.path.length - 1];
    
    require(amountOut >= minOut, "Slippage exceeded");
}

function _validateAllocation() internal view returns (bool) {
    uint256 nav = calculateNAV();
    
    for (uint i = 0; i < allowedAssets.length; i++) {
        address asset = allowedAssets[i];
        uint256 currentWeight = _getAssetWeight(asset, nav);
        uint256 targetWeight = targetWeights[asset];
        
        uint256 deviation = currentWeight > targetWeight 
            ? currentWeight - targetWeight 
            : targetWeight - currentWeight;
            
        if (deviation > weightTolerance) {
            return false;
        }
    }
    return true;
}
```

**Managers cannot override constraints**. Reverts enforce rules.

---

### 4. Fee Accrual

**Management Fee** (continuous accrual):

```solidity
function accrueManagementFee() public {
    uint256 timeSinceLastCollection = block.timestamp - lastFeeCollection;
    if (timeSinceLastCollection == 0) return;
    
    // Annual fee prorated
    uint256 nav = calculateNAV();
    uint256 feeAmount = (nav * managementFee * timeSinceLastCollection) 
                        / (10000 * 365 days);
    
    // Mint new shares to manager (dilution model)
    uint256 supply = totalSupply();
    uint256 sharesToMint = (feeAmount * supply) / (nav - feeAmount);
    
    _mint(manager, sharesToMint);
    lastFeeCollection = block.timestamp;
    
    emit ManagementFeeCollected(sharesToMint, feeAmount);
}
```

**Performance Fee** (high-water mark):

```solidity
function collectPerformanceFee() external {
    uint256 currentPricePerShare = getSharePrice();
    
    // Only collect if above high water mark
    if (currentPricePerShare <= highWaterMark) return;
    
    uint256 profit = currentPricePerShare - highWaterMark;
    uint256 feeAmount = (profit * performanceFee) / 10000;
    
    // Mint shares to manager
    uint256 supply = totalSupply();
    uint256 sharesToMint = (feeAmount * supply) / currentPricePerShare;
    
    _mint(manager, sharesToMint);
    highWaterMark = currentPricePerShare;
    
    emit PerformanceFeeCollected(sharesToMint, feeAmount);
}
```

**On-chain. Transparent. Impossible to front-run.**

---

### 5. Redemptions (Burning Shares)

**User flow**:

```solidity
function redeem(uint256 shares) external nonReentrant {
    require(shares > 0 && shares <= balanceOf(msg.sender), "Invalid amount");
    
    // Accrue fees before redemption
    accrueManagementFee();
    
    // Calculate user's share of NAV
    uint256 nav = calculateNAV();
    uint256 totalShares = totalSupply();
    uint256 userNAV = (nav * shares) / totalShares;
    
    // Burn shares
    _burn(msg.sender, shares);
    
    // Withdraw proportional assets
    _withdrawProportionalAssets(msg.sender, shares, totalShares);
    
    emit Redemption(msg.sender, shares, userNAV);
}
```

**Asset withdrawal**:

```solidity
function _withdrawProportionalAssets(
    address user, 
    uint256 shares, 
    uint256 totalShares
) internal {
    for (uint i = 0; i < allowedAssets.length; i++) {
        address asset = allowedAssets[i];
        uint256 assetBalance = getAssetBalance(asset);
        uint256 userShare = (assetBalance * shares) / totalShares;
        
        IERC20(asset).transfer(user, userShare);
    }
}
```

**Optional single-asset redemption**:

```solidity
function redeemToSingleAsset(
    uint256 shares, 
    address outputAsset
) external nonReentrant {
    // ... same validation ...
    
    // Withdraw proportional assets to contract
    _withdrawProportionalAssets(address(this), shares, totalShares);
    
    // Swap all assets to outputAsset
    uint256 totalOutput = 0;
    for (uint i = 0; i < allowedAssets.length; i++) {
        if (allowedAssets[i] != outputAsset) {
            uint256 amount = getAssetBalance(allowedAssets[i]);
            totalOutput += _swapOnDEX(allowedAssets[i], outputAsset, amount);
        } else {
            totalOutput += getAssetBalance(outputAsset);
        }
    }
    
    // Optional exit fee
    uint256 exitFee = (totalOutput * exitFeeRate) / 10000;
    totalOutput -= exitFee;
    
    IERC20(outputAsset).transfer(msg.sender, totalOutput);
}
```

---

## Price & NAV Calculation

**Core NAV function**:

```solidity
function calculateNAV() public view returns (uint256) {
    uint256 totalValue = 0;
    
    for (uint i = 0; i < allowedAssets.length; i++) {
        address asset = allowedAssets[i];
        uint256 balance = getAssetBalance(asset);
        uint256 price = IPriceOracle(priceOracle).getPrice(asset);
        
        totalValue += (balance * price) / 1e18;
    }
    
    return totalValue;
}
```

**Oracle integration**:

```solidity
interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);
    function getPriceWithFallback(address asset) external view returns (uint256, bool);
}
```

**Oracle options on BNB Chain**:

* Chainlink (primary)
* Binance Oracle
* Pyth (cross-chain)
* RedStone

**Fallback logic**:

```solidity
function _getSafePrice(address asset) internal view returns (uint256) {
    (uint256 primaryPrice, bool primaryValid) = 
        IPriceOracle(priceOracle).getPriceWithFallback(asset);
    
    if (primaryValid) {
        // Check if price is within reasonable bounds
        uint256 secondaryPrice = ISecondaryOracle(fallbackOracle).getPrice(asset);
        uint256 deviation = _calculateDeviation(primaryPrice, secondaryPrice);
        
        require(deviation < MAX_PRICE_DEVIATION, "Oracle deviation too high");
        return primaryPrice;
    }
    
    revert("Oracle failure");
}
```

**NAV update triggers**:

* On deposit
* On withdrawal
* On rebalance
* Manual sync call (anyone can call, gas-optimized)

---

## Governance & Safety

### Manager Permissions

**Manager CAN**:

```solidity
function proposeRebalance() external onlyManager;
function executeRebalance() external onlyManager;
function updateStrategyMetadata(string calldata newIpfsHash) external onlyManager;
```

**Manager CANNOT**:

```solidity
// NO withdrawal functions exist for manager
// NO ability to change fees mid-flight
// NO ability to add assets without timelock

function emergencyWithdraw() external onlyManager {
    revert("Not allowed"); // Doesn't exist
}
```

**Adding new assets** (with 7-day timelock):

```solidity
mapping(address => uint256) public proposedAssets;

function proposeNewAsset(address asset, uint256 weight) external onlyManager {
    proposedAssets[asset] = block.timestamp + 7 days;
    emit AssetProposed(asset, weight);
}

function executeAssetAddition(address asset, uint256 weight) external onlyManager {
    require(proposedAssets[asset] != 0, "Not proposed");
    require(block.timestamp >= proposedAssets[asset], "Timelock active");
    
    allowedAssets.push(asset);
    isAllowedAsset[asset] = true;
    targetWeights[asset] = weight;
    
    delete proposedAssets[asset];
}
```

---

### Emergency Controls

**Circuit breakers**:

```solidity
modifier whenNotPaused() {
    require(!isPaused, "Paused");
    _;
}

function pause() external onlyManager {
    isPaused = true;
    emit Paused();
}

function unpause() external onlyManager {
    isPaused = false;
    emit Unpaused();
}
```

**Emergency mode** (oracle failure / extreme volatility):

```solidity
function enableEmergencyMode() external {
    require(msg.sender == manager || _oracleHasFailed(), "Not authorized");
    isEmergencyMode = true;
    emit EmergencyModeEnabled();
}

function emergencyRedeem(uint256 shares) external {
    require(isEmergencyMode, "Not in emergency");
    // Use last known good NAV or proportional asset withdrawal
    _emergencyWithdraw(msg.sender, shares);
}
```

**Graceful exit for investors**:

* Redemptions always enabled (even when paused)
* Proportional asset withdrawal if NAV calculation fails
* Time-weighted average price (TWAP) fallback

---

## Gas Optimization (BNB Chain Specific)

**Why this matters**: BNB Chain has lower gas than Ethereum, but frequent operations still need optimization.

**Techniques used**:

1. **Immutable variables** for constants
2. **Packed storage** for related variables
3. **Batch operations** for multi-asset trades
4. **View function caching** (off-chain NAV reads)
5. **Lazy fee accrual** (only on user interactions)

```solidity
// Storage packing example
struct FundConfig {
    uint128 managementFee;      // Pack into single slot
    uint128 performanceFee;
    uint128 maxSlippage;
    uint128 weightTolerance;
}
```

**Estimated gas costs**:

* Deposit: ~150k gas
* Redemption: ~120k gas
* Rebalance (3 assets): ~200k gas
* Fee accrual: ~50k gas

At 3 Gwei and $600 BNB = **$0.05-0.40 per operation**

---

## Optional Extensions (Phase 2+)

### Fund-of-Funds

```solidity
contract FundOfFunds is TradCemFund {
    // Allow other TradCem funds as "assets"
    mapping(address => bool) public isChildFund;
    
    function depositIntoChildFund(address childFund, uint256 amount) external onlyManager {
        require(isChildFund[childFund], "Not approved child fund");
        // Buy child fund shares
    }
}
```

### DAO-Controlled Funds

```solidity
contract DAOFund is TradCemFund {
    IGovernor public governor;
    
    modifier onlyGovernance() {
        require(msg.sender == address(governor), "Not governance");
        _;
    }
    
    // Rebalancing requires DAO vote
    function rebalance() external override onlyGovernance {
        super.rebalance();
    }
}
```

### NFT Access Tiers

```solidity
contract TieredFund is TradCemFund {
    IERC721 public accessNFT;
    mapping(uint256 => FeeDiscount) public tierDiscounts;
    
    function deposit(uint256 amount, uint256 nftId) external {
        require(accessNFT.ownerOf(nftId) == msg.sender, "Not NFT owner");
        // Apply discount tier
    }
}
```

### Strategy IP Tokenization

```solidity
contract StrategyNFT is ERC721 {
    // Manager can mint NFT representing strategy
    // NFT owner receives portion of management fees
    mapping(uint256 => address) public strategyFunds;
}
```

---

## Integration Points

### DEX Routers (BNB Chain)

**PancakeSwap V3**:

```solidity
interface IPancakeRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}
```

**Aggregators**:

* 1inch (multi-DEX routing)
* ParaSwap
* OpenOcean

### Oracle Providers

**Chainlink**:

```solidity
interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}
```

### Lending Protocols (Future)

* Venus Protocol (money markets)
* Radiant Capital
* Enable fund assets to earn yield while idle

---

## Security Considerations

### Critical Invariants

1. **Conservation**: `sum(assetBalances * prices) == NAV`
2. **Fairness**: Share price = NAV / supply
3. **Isolation**: Manager cannot withdraw user funds
4. **Atomicity**: Deposits/withdrawals are atomic or revert

### Audit Focus Areas

* Reentrancy protection (especially on redemptions)
* Oracle manipulation resistance
* Integer overflow/underflow (use Solidity 0.8+)
* Access control on privileged functions
* MEV resistance in rebalancing

### Known Limitations

* Oracle dependency (no decentralized pricing without oracles)
* DEX liquidity constraints (large rebalances may have slippage)
* Gas costs scale with number of assets
* No cross-chain assets (yet)

---

## Deployment Checklist

**Pre-launch**:

- [ ] Deploy FundFactory
- [ ] Deploy PriceOracle wrapper
- [ ] Whitelist DEX routers
- [ ] Set emergency multisig
- [ ] Verify all contracts on BscScan
- [ ] Run gas profiling
- [ ] Complete security audit

**Post-launch**:

- [ ] Monitor oracle health
- [ ] Track gas costs
- [ ] Set up off-chain indexer (The Graph)
- [ ] Build frontend dashboards
- [ ] Implement automated rebalancing bot

---

## Contract Addresses (Example Structure)

```
FundFactory: 0x...
PriceOracle: 0x...
PancakeRouter: 0x10ED43C718714eb63d5aA57B78B54704E256024E
ChainlinkRegistry: 0x...
EmergencyMultisig: 0x...
```

---

# WHAT USERS SHOULD EXPECT

## For Investors

* You are not copying trades
* You are buying **exposure to a portfolio**
* You can see (on BscScan):

  * All assets and balances
  * Historical weights and rebalances
  * Fee collections
  * Manager actions
* You can exit anytime at fair NAV
* Your funds are **locked in smart contracts**
* No custodial risk

This feels like:

> "Owning a transparent, permissionless index fund on-chain"

---

## For Creators / Managers

* You don't touch user funds (literally cannot)
* You earn through **performance and management fees**
* Your reputation **compounds on-chain**
* Your strategy becomes a **public, composable asset**
* You compete on:

  * Risk-adjusted returns
  * Consistency
  * Fee efficiency
  * Transparency

Not screenshots. Not hype.

---

## One-Sentence Summary

> TradCem funds are EVM smart contracts that turn portfolio strategies into transparent, rule-enforced, non-custodial financial instruments on BNB Chain.

---

## What You Can Build Next

**Immediate next steps**:

* Full Solidity implementation (Hardhat/Foundry)
* Unit tests (100% coverage target)
* Integration tests with PancakeSwap forks
* Gas optimization benchmarks
* Frontend React SDK

**Advanced features**:

* Automated rebalancing keeper network
* On-chain performance analytics
* Subgraph for historical data
* Mobile app integration
* Cross-chain bridge for multi-chain portfolios

This is **production-grade infrastructure thinking**.

Now it's about **building it right**.