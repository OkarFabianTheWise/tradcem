# 🚀 TradCem Testnet Deployment - Quick Start

## Current Status: Ready for Deployment!

All 7 MVP contracts are implemented and ready for BNB Chain testnet deployment.

## Option 1: Automated Deployment (Recommended)

### Prerequisites
1. **Get testnet BNB**: Visit [BNB Chain Faucet](https://testnet.binance.org/faucet-smart)
2. **Set up MetaMask** for BSC Testnet (Chain ID: 97)
3. **Get your private key** from MetaMask (export carefully!)

### Quick Deploy Commands

```bash
# 1. Install dependencies (if network works)
npm install

# 2. Set up environment
cp .env.example .env
# Edit .env with your PRIVATE_KEY and BSCSCAN_API_KEY

# 3. Deploy infrastructure
npm run deploy:testnet

# 4. Update fund creation script with deployed addresses
# Edit scripts/create-fund.js with the output addresses

# 5. Create your first fund
npm run create-fund:testnet
```

## Option 2: Manual Deployment (If npm fails)

### Step 1: Deploy via Remix IDE

1. Go to [Remix IDE](https://remix.ethereum.org/)
2. Create new files and copy our contract code:
   - `contracts/PriceOracle.sol`
   - `contracts/DEXRouter.sol`
   - `contracts/FeeCollector.sol`
   - `contracts/RebalanceValidator.sol`
   - `contracts/EmergencyModule.sol`
   - `contracts/FundFactory.sol`

3. **Deploy Order:**
   - ✅ PriceOracle (no constructor args)
   - ✅ DEXRouter (`0x1b81D678ffb9C0263b24A97847620C99d213eB14`, `0x000...`, `0x000...`)
   - ✅ FeeCollector (no args)
   - ✅ RebalanceValidator (no args)
   - ✅ EmergencyModule (`your_address`)
   - ✅ FundFactory (no args)

### Step 2: Configure Contracts

After deployment, call these functions:

**PriceOracle:**
```javascript
// Add testnet assets
await priceOracle.addAsset("0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7", "0x000...", "0x000...", "0x000..."); // BUSD
await priceOracle.addAsset("0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd", "0x000...", "0x000...", "0x000..."); // WBNB
await priceOracle.addAsset("0xFa60D973F7642B748046464e165A65B7323b0DEE", "0x000...", "0x000...", "0x000..."); // CAKE
```

**FeeCollector:**
```javascript
await feeCollector.addSupportedToken("0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7"); // BUSD
await feeCollector.addSupportedToken("0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd"); // WBNB
```

### Step 3: Create Your First Fund

Use FundFactory to create a fund:

```javascript
await fundFactory.createFund(
  "TradCem Balanced Fund",     // name
  "TCBF",                      // symbol
  "your_address",              // manager
  ["0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7", "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd", "0xFa60D973F7642B748046464e165A65B7323b0DEE"], // assets
  [5000, 3000, 2000],         // weights (50%, 30%, 20%)
  priceOracleAddress,          // price oracle
  dexRouterAddress,            // dex router
  feeCollectorAddress,         // fee collector
  rebalanceValidatorAddress,   // rebalance validator
  emergencyModuleAddress,      // emergency module
  200,                         // management fee (2%)
  2000,                        // performance fee (20%)
  604800,                      // rebalance interval (7 days)
  500,                         // weight tolerance (5%)
  "0x" + ethers.utils.keccak256(ethers.utils.toUtf8Bytes("tradcem-v1")).slice(2) // salt
);
```

## Testnet Addresses

### BNB Chain Testnet
- **RPC**: `https://bsc-testnet.publicnode.com`
- **Chain ID**: 97
- **Block Explorer**: [BscScan Testnet](https://testnet.bscscan.com/)

### Testnet Tokens
- **BUSD**: `0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7`
- **WBNB**: `0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd`
- **CAKE**: `0xFa60D973F7642B748046464e165A65B7323b0DEE`

### DEX
- **PancakeSwap Router**: `0x1b81D678ffb9C0263b24A97847620C99d213eB14`

## Testing Your Fund

1. **Get test tokens** from faucets
2. **Approve BUSD** spending to fund
3. **Deposit** to mint shares
4. **Test rebalancing** as manager
5. **Withdraw** to burn shares

## Troubleshooting

### Common Issues
- **"insufficient funds"**: Get more testnet BNB
- **"execution reverted"**: Check constructor arguments
- **Network slow**: BSC testnet can be congested

### Gas Costs (approx)
- Deploy contract: 2-4M gas (~$4-8 at 20 gwei)
- Create fund: 3-5M gas (~$6-10)
- Deposit/withdraw: 150-300k gas (~$0.30-0.60)

## Next Steps After Deployment

1. ✅ **Verify contracts** on BscScan
2. ✅ **Write unit tests** 
3. ✅ **Integration testing**
4. ✅ **Gas optimization**
5. ✅ **Security audit**

---

**🎉 Ready to deploy TradCem on testnet! Let's make portfolio management transparent and on-chain.**