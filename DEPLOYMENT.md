# TradCem Deployment Guide

## Prerequisites

1. **Node.js** (v16 or higher)
2. **npm** or **yarn**
3. **MetaMask** or other Web3 wallet with BNB Chain testnet BNB
4. **BSCScan API Key** for contract verification

## Setup

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Create environment file:**
   ```bash
   cp .env.example .env
   ```
   Edit `.env` with your:
   - Private key (without 0x prefix)
   - BSCScan API key

3. **Fund your wallet with testnet BNB:**
   - Get from [BNB Chain Faucet](https://testnet.binance.org/faucet-smart)
   - Or use [BNB Chain Testnet Faucet](https://testnet.bnbchain.org/faucet-smart)

## Deployment Steps

### 1. Deploy Infrastructure Contracts

```bash
npx hardhat run scripts/deploy.js --network bscTestnet
```

This deploys:
- ✅ PriceOracle
- ✅ DEXRouter
- ✅ FeeCollector
- ✅ RebalanceValidator
- ✅ EmergencyModule
- ✅ FundFactory

**Save the output addresses!** You'll need them for the next step.

### 2. Update Fund Creation Script

Edit `scripts/create-fund.js` and replace the placeholder addresses in `DEPLOYMENT_ADDRESSES` with the actual deployed contract addresses from step 1.

### 3. Create Your First Fund

```bash
npx hardhat run scripts/create-fund.js --network bscTestnet
```

This creates a sample fund with:
- 50% BUSD, 30% WBNB, 20% CAKE
- 2% management fee
- 20% performance fee
- 7-day rebalance interval

### 4. Verify Contracts on BSCScan

```bash
npx hardhat verify --network bscTestnet CONTRACT_ADDRESS "Constructor arguments..."
```

## Testing the Fund

### Get Test Tokens
- **BUSD**: Use the [BUSD Faucet](https://testnet.binance.org/faucet-smart)
- **CAKE**: Swap some BNB for CAKE on [PancakeSwap Testnet](https://pancakeswap.finance/)

### Test Deposit
```javascript
// Approve BUSD spending
await busdContract.approve(fundAddress, depositAmount);

// Deposit to fund
await fundContract.deposit(depositAmount);
```

### Test Rebalancing
```javascript
// As manager, trigger rebalance
await fundContract.rebalance();
```

## Contract Addresses (BSC Testnet)

### Infrastructure
- **FundFactory**: [Deployed Address]
- **PriceOracle**: [Deployed Address]
- **DEXRouter**: [Deployed Address]
- **FeeCollector**: [Deployed Address]
- **RebalanceValidator**: [Deployed Address]
- **EmergencyModule**: [Deployed Address]

### Sample Fund
- **TradCem Balanced Fund**: [Fund Address]

### Testnet Tokens
- **BUSD**: `0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7`
- **WBNB**: `0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd`
- **CAKE**: `0xFa60D973F7642B748046464e165A65B7323b0DEE`

## Troubleshooting

### Common Issues

1. **Insufficient funds**: Make sure you have enough testnet BNB (at least 0.1 BNB)
2. **Network timeout**: BSC testnet can be slow, try again
3. **Contract verification fails**: Check constructor arguments match exactly

### Gas Estimation
- Infrastructure deployment: ~2-3 BNB
- Fund creation: ~1-2 BNB
- Fund operations: ~0.01-0.05 BNB

## Next Steps

1. **Write comprehensive tests** with Hardhat
2. **Add more assets** to the price oracle
3. **Implement real price feeds** (Chainlink, Pyth)
4. **Test emergency functions**
5. **Audit preparation**

## Security Notes

- ✅ Never commit private keys to git
- ✅ Test thoroughly on testnet before mainnet
- ✅ Get professional audit before mainnet deployment
- ✅ Use multisig for emergency controls in production