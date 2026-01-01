# 🚀 TradCem Automated Testnet Deployment

## Prerequisites ✅
- ✅ Node.js installed
- ✅ MetaMask with BSC Testnet
- ✅ Test BNB in your wallet
- ✅ `.env` file configured with your private key

## One-Command Full Deployment

```bash
npm run full-deploy:testnet
```

This single command will:
1. ✅ Deploy all 6 infrastructure contracts
2. ✅ Configure price feeds and supported tokens
3. ✅ Create a sample balanced fund (50% BUSD, 30% WBNB, 20% CAKE)
4. ✅ Save all addresses to `deployments/testnet.json`
5. ✅ Display complete deployment summary

## What Gets Deployed

### Infrastructure (6 contracts)
- **PriceOracle**: Multi-source price feeds
- **DEXRouter**: PancakeSwap integration with slippage protection
- **FeeCollector**: Transparent fee accounting
- **RebalanceValidator**: Constraint validation logic
- **EmergencyModule**: Circuit breakers and safety controls
- **FundFactory**: Deterministic fund deployment via CREATE2

### Sample Fund
- **TradCem Balanced Fund (TCBF)**
- 50% BUSD, 30% WBNB, 20% CAKE allocation
- 2% management fee, 20% performance fee
- 7-day rebalance interval
- ERC20 shares with transparent NAV

## Test the Fund

After deployment, test with:

```bash
npm run test-fund:testnet
```

This will:
- Check your BUSD balance
- Deposit 0.1 BUSD → mint shares
- Withdraw shares → receive proportional assets
- Verify NAV calculations

## Manual Steps (if needed)

### Get Test Tokens
```javascript
// Get BUSD from faucet
// https://testnet.binance.org/faucet-smart

// Or swap BNB for BUSD on PancakeSwap testnet
```

### Test Operations
```javascript
// Load deployment info
const deployment = require('./deployments/testnet.json');
const fundAddress = deployment.funds[0].address;

// Get contract
const fund = await ethers.getContractAt("TradCemFund", fundAddress);

// Approve and deposit
await busd.approve(fundAddress, amount);
await fund.deposit(amount);

// Check your shares
const shares = await fund.balanceOf(yourAddress);

// Redeem shares
await fund.redeem(shares);
```

## Contract Addresses (Testnet)

After deployment, check `deployments/testnet.json` for all addresses.

### Key Addresses:
- **Fund**: Your deployed fund address
- **BUSD**: `0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7`
- **WBNB**: `0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd`
- **CAKE**: `0xFa60D973F7642B748046464e165A65B7323b0DEE`

## Troubleshooting

### Common Issues
- **"insufficient funds"**: Get more testnet BNB
- **"execution reverted"**: Check constructor arguments
- **Network timeout**: BSC testnet can be slow, retry

### Gas Costs (approx)
- Full deployment: ~5-8 BNB
- Individual operations: ~0.01-0.05 BNB

## Next Steps After Testing

1. ✅ **Verify contracts** on BscScan
2. ✅ **Write comprehensive tests**
3. ✅ **Add more assets** (real price feeds)
4. ✅ **Test rebalancing** with real DEX
5. ✅ **Security audit** preparation

---

**🎯 Ready to deploy TradCem on testnet? Just run:**

```bash
npm run full-deploy:testnet
```

**Then test it:**

```bash
npm run test-fund:testnet
```

**Happy deploying! 🚀**