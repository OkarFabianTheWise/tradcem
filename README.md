# TradCem On-Chain Fund System

A complete decentralized fund management system on BNB Chain, enabling transparent, rules-based portfolio management with automated rebalancing and fee collection.

## 🚀 Live Deployment (BNB Chain Testnet)

**Status**: ✅ Successfully Deployed

### Contract Addresses

| Contract | Address | BscScan Link |
|----------|---------|--------------|
| **TradCemFund** | `0x9a490F2CCFad1C06A88fA36F44196A9A0b588Bb8` | [View](https://testnet.bscscan.com/address/0x9a490F2CCFad1C06A88fA36F44196A9A0b588Bb8) |
| **FundFactory** | `0x4B56686Ef0C430d934C6D45bA955b1bBC81609DC` | [View](https://testnet.bscscan.com/address/0x4B56686Ef0C430d934C6D45bA955b1bBC81609DC) |
| **PriceOracle** | `0xb27B9dF2A8E88847ED9eaF2937dA55f17C34f34E` | [View](https://testnet.bscscan.com/address/0xb27B9dF2A8E88847ED9eaF2937dA55f17C34f34E) |
| **DEXRouter** | `0x13D24e89468B9aF9e1eeCff3D224be940Cd67aF3` | [View](https://testnet.bscscan.com/address/0x13D24e89468B9aF9e1eeCff3D224be940Cd67aF3) |
| **FeeCollector** | `0xdCDe4AdC522c8eae8992693544F3336B9C96BB6b` | [View](https://testnet.bscscan.com/address/0xdCDe4AdC522c8eae8992693544F3336B9C96BB6b) |
| **RebalanceValidator** | `0x75Fa95d6851dA49c3AA7E896B0Ad2bbeFd151eeA` | [View](https://testnet.bscscan.com/address/0x75Fa95d6851dA49c3AA7E896B0Ad2bbeFd151eeA) |
| **EmergencyModule** | `0xB4d662074b99172e1D7ad13247940150213448Be` | [View](https://testnet.bscscan.com/address/0xB4d662074b99172e1D7ad13247940150213448Be) |

### Sample Fund Details

- **Name**: TradCem Balanced Fund
- **Symbol**: TCBF
- **Manager**: `0x115435e14798a90dbd8849483CCE10d3DB502c23`
- **Assets**: BUSD (50%), WBNB (30%), CAKE (20%)
- **Management Fee**: 2% annually
- **Performance Fee**: 20%

### Test the Fund

1. **Get Test Tokens**:
   - BUSD: [BNB Chain Faucet](https://testnet.binance.org/faucet-smart)
   - WBNB/CAKE: Available on PancakeSwap testnet

2. **Interact with Fund**:
   ```javascript
   // Deposit BUSD to mint shares
   fund.deposit(amount)
   
   // Check your balance
   fund.balanceOf(userAddress)
   
   // Redeem shares for underlying assets
   fund.redeem(shares)
   
   // Manager rebalance (rules-based)
   fund.rebalance()
   ```

## Features

- **7 Smart Contracts**: Complete fund infrastructure including PriceOracle, DEXRouter, FeeCollector, RebalanceValidator, EmergencyModule
- **ERC-20 Fund Shares**: Investors mint/burn shares based on NAV
- **Automated Rebalancing**: Rules-based portfolio adjustments with slippage protection
- **Transparent Fee Collection**: Management and performance fees with automatic distribution
- **Emergency Controls**: Circuit breakers and safety mechanisms
- **Multi-Source Price Feeds**: Chainlink, Binance, and Pyth oracle integration

## Quick Start

### Prerequisites

1. **Node.js** >= 16.0.0
2. **Yarn** package manager
3. **BNB Chain Testnet Account** with BNB for gas fees

### Installation

```bash
git clone <repository-url>
cd tradcem
yarn install
```

### Environment Setup

1. Copy the environment template:
```bash
cp .env.example .env
```

2. Edit `.env` and add your private key:
```env
PRIVATE_KEY=your_private_key_without_0x_prefix
BSCSCAN_API_KEY=your_bscscan_api_key
```

3. Fund your account with test BNB:
   - Visit [BNB Chain Faucet](https://testnet.binance.org/faucet-smart)
   - Send test BNB to your account

### Deployment

Deploy the complete system to BNB Chain Testnet:

```bash
# Deploy infrastructure + create sample fund
yarn full-deploy:testnet

# Or deploy step-by-step:
yarn deploy:testnet           # Deploy contracts
yarn create-fund:testnet      # Create fund instance
yarn test-fund:testnet        # Test fund operations
```

### Local Development

For testing without testnet deployment:

```bash
# Start local Hardhat network
yarn hardhat node

# Deploy to local network (in another terminal)
yarn hardhat run scripts/full-deploy.js --network hardhat
```

## User Interface

A modern React application for interacting with the TradCem fund system.

### Features

- **Home Page**: Landing page with fund overview and live statistics
- **Fund Dashboard**: Interactive interface for deposits, withdrawals, and portfolio management
- **Wallet Integration**: MetaMask connection for blockchain interactions
- **Dark Theme**: Modern UI with green accent colors and glow effects
- **Responsive Design**: Mobile-first design with Tailwind CSS

### Running the UI

```bash
cd ui
yarn install
yarn start
```

The UI will be available at [http://localhost:3000](http://localhost:3000).

### UI Components

- **Home**: Landing page with hero section and fund statistics
- **FundDashboard**: Main interface for fund interactions including:
  - Fund overview and key metrics
  - Asset allocation display
  - Deposit/withdraw actions
  - Contract address information

## Contract Architecture

### Core Contracts

1. **FundFactory** - Deploys new fund instances with CREATE2
2. **TradCemFund** - Main fund logic with ERC-20 shares
3. **PriceOracle** - Multi-source price aggregation
4. **DEXRouter** - PancakeSwap integration with slippage protection
5. **FeeCollector** - Transparent fee management
6. **RebalanceValidator** - Constraint validation for rebalancing
7. **EmergencyModule** - Safety controls and circuit breakers

### Key Features

- **NAV Calculation**: Real-time Net Asset Value computation
- **Proportional Rebalancing**: Maintains target allocations
- **Slippage Protection**: DEX trade safety mechanisms
- **Emergency Pause**: Manager-controlled circuit breakers
- **Immutable Rules**: Strategy constraints enforced on-chain

## Testing

```bash
# Run all tests
yarn test

# Run with coverage
yarn test:coverage
```

## Deployment Addresses

After successful deployment, contract addresses are saved to `deployments/testnet.json`.

## Security

- **Non-custodial**: Users control their own funds
- **Rules-based**: All operations validated against constraints
- **Emergency controls**: Manager can pause but not withdraw
- **Transparent fees**: All fee collection is on-chain and verifiable

## License

MIT</content>
<parameter name="filePath">/home/orkarfabianthewise/code/tradcem/README.md