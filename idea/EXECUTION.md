<!-- Set and tick progress -->

# TRADCEM DEVELOPMENT EXECUTION PLAN

## Phase 1: MVP (7 Contracts) - START HERE

### Core Contracts (Tier 1)
- [x] **FundFactory.sol** - Deploy and register new funds (~300 lines)
- [x] **TradCemFund.sol** - Main fund logic (deposits, withdrawals, rebalancing) (~800-1000 lines)
- [x] **PriceOracle.sol** - Aggregate price feeds from multiple sources (~400 lines)
- [x] **DEXRouter.sol** - Abstract DEX interactions, add slippage protection (~300 lines)
- [x] **FeeCollector.sol** - Separate fee accounting and distribution (~200 lines)
- [x] **RebalanceValidator.sol** - Validate rebalance operations meet constraints (~250 lines)
- [x] **EmergencyModule.sol** - Circuit breakers and emergency functions (~150 lines)

### Development Milestones
- [x] Set up project structure (Hardhat/Foundry)
- [ ] Implement all 7 contracts
- [x] Create deployment scripts and configuration
- [x] Automate full deployment process (infrastructure + fund)
- [ ] Deploy on BNB Chain testnet
- [ ] Write unit tests (100% coverage target)
- [ ] Integration tests with PancakeSwap forks
- [ ] Gas optimization benchmarks
- [ ] Security audit preparation
- [ ] Testnet deployment

### Timeline
- Month 1-2: Build MVP (7 contracts)
- Month 2-3: Test + audit
- Month 3: Deploy testnet
- Month 4: Deploy mainnet MVP

**Status**: Fully automated deployment ready! Run 'npm run full-deploy:testnet' to deploy everything.