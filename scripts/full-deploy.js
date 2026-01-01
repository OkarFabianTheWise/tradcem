const { ethers } = require("hardhat");
const fs = require('fs');

async function main() {
    console.log("🚀 TradCem Full Deployment - Infrastructure + Fund\n");

    const [deployer] = await ethers.getSigners();
    console.log("Deploying with account:", deployer.address);
    console.log("Account balance:", ethers.utils.formatEther(await deployer.getBalance()), "BNB\n");

    const deployedContracts = {};

    // === PHASE 1: Deploy Infrastructure ===

    console.log("📦 PHASE 1: Deploying Infrastructure Contracts\n");

    // Deploy PriceOracle first
    console.log("📊 Deploying PriceOracle...");
    const PriceOracle = await ethers.getContractFactory("PriceOracle");
    const priceOracle = await PriceOracle.deploy();
    await priceOracle.deployed();
    console.log("✅ PriceOracle deployed to:", priceOracle.address);
    deployedContracts.priceOracle = priceOracle.address;

    // Deploy DEXRouter
    console.log("🔄 Deploying DEXRouter...");
    const DEXRouter = await ethers.getContractFactory("DEXRouter");
    const pancakeRouter = "0x1b81D678ffb9C0263b24A97847620C99d213eB14";
    const dexRouter = await DEXRouter.deploy(pancakeRouter, ethers.constants.AddressZero, ethers.constants.AddressZero);
    await dexRouter.deployed();
    console.log("✅ DEXRouter deployed to:", dexRouter.address);
    deployedContracts.dexRouter = dexRouter.address;

    // Deploy FeeCollector
    console.log("💰 Deploying FeeCollector...");
    const FeeCollector = await ethers.getContractFactory("FeeCollector");
    const feeCollector = await FeeCollector.deploy();
    await feeCollector.deployed();
    console.log("✅ FeeCollector deployed to:", feeCollector.address);
    deployedContracts.feeCollector = feeCollector.address;

    // Deploy RebalanceValidator
    console.log("⚖️ Deploying RebalanceValidator...");
    const RebalanceValidator = await ethers.getContractFactory("RebalanceValidator");
    const rebalanceValidator = await RebalanceValidator.deploy();
    await rebalanceValidator.deployed();
    console.log("✅ RebalanceValidator deployed to:", rebalanceValidator.address);
    deployedContracts.rebalanceValidator = rebalanceValidator.address;

    // Deploy EmergencyModule
    console.log("🚨 Deploying EmergencyModule...");
    const EmergencyModule = await ethers.getContractFactory("EmergencyModule");
    const emergencyModule = await EmergencyModule.deploy(deployer.address);
    await emergencyModule.deployed();
    console.log("✅ EmergencyModule deployed to:", emergencyModule.address);
    deployedContracts.emergencyModule = emergencyModule.address;

    // Deploy FundFactory
    console.log("🏭 Deploying FundFactory...");
    const FundFactory = await ethers.getContractFactory("FundFactory");
    const fundFactory = await FundFactory.deploy();
    await fundFactory.deployed();
    console.log("✅ FundFactory deployed to:", fundFactory.address);
    deployedContracts.fundFactory = fundFactory.address;

    // === PHASE 2: Configure Infrastructure ===

    console.log("\n⚙️ PHASE 2: Configuring Infrastructure\n");

    // Asset addresses on BSC Testnet
    const ASSETS = {
        BUSD: "0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7",
        WBNB: "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd",
        CAKE: "0xFa60D973F7642B748046464e165A65B7323b0DEE",
    };

    console.log("Adding BUSD to PriceOracle...");
    await priceOracle.addAsset(ASSETS.BUSD, ethers.utils.hexZeroPad("0x01", 20), ethers.constants.AddressZero, ethers.constants.AddressZero);
    console.log("✅ Added BUSD");

    console.log("Adding WBNB to PriceOracle...");
    await priceOracle.addAsset(ASSETS.WBNB, ethers.utils.hexZeroPad("0x02", 20), ethers.constants.AddressZero, ethers.constants.AddressZero);
    console.log("✅ Added WBNB");

    console.log("Adding CAKE to PriceOracle...");
    await priceOracle.addAsset(ASSETS.CAKE, ethers.utils.hexZeroPad("0x03", 20), ethers.constants.AddressZero, ethers.constants.AddressZero);
    console.log("✅ Added CAKE");

    console.log("Adding supported tokens to FeeCollector...");
    await feeCollector.addSupportedToken(ASSETS.BUSD);
    await feeCollector.addSupportedToken(ASSETS.WBNB);
    console.log("✅ Added supported tokens");

    // === PHASE 3: Create Sample Fund ===

    console.log("\n🏗️ PHASE 3: Creating Sample Fund\n");

    // Sample fund configuration
    const fundConfig = {
        name: "TradCem Balanced Fund",
        symbol: "TCBF",
        manager: deployer.address,
        allowedAssets: [ASSETS.BUSD, ASSETS.WBNB, ASSETS.CAKE],
        targetWeights: [5000, 3000, 2000], // 50% BUSD, 30% WBNB, 20% CAKE
        priceOracle: deployedContracts.priceOracle,
        dexRouter: deployedContracts.dexRouter,
        feeCollector: deployedContracts.feeCollector,
        rebalanceValidator: deployedContracts.rebalanceValidator,
        emergencyModule: deployedContracts.emergencyModule,
        managementFee: 200, // 2%
        performanceFee: 2000, // 20%
        rebalanceInterval: 7 * 24 * 60 * 60, // 7 days
        weightTolerance: 500, // 5%
        salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("tradcem-balanced-fund-v1")),
    };

    console.log("Fund Configuration:");
    console.log("- Name:", fundConfig.name);
    console.log("- Symbol:", fundConfig.symbol);
    console.log("- Assets:", fundConfig.allowedAssets);
    console.log("- Weights:", fundConfig.targetWeights.map(w => w / 100 + "%"));
    console.log("- Management Fee:", fundConfig.managementFee / 100 + "%");
    console.log("- Performance Fee:", fundConfig.performanceFee / 100 + "%");

    // Compute fund address
    console.log("\n🔮 Computing fund address...");
    const computedAddress = await fundFactory.computeFundAddress(
        fundConfig.name,
        fundConfig.symbol,
        fundConfig.manager,
        fundConfig.allowedAssets,
        fundConfig.targetWeights,
        fundConfig.priceOracle,
        fundConfig.dexRouter,
        fundConfig.feeCollector,
        fundConfig.rebalanceValidator,
        fundConfig.emergencyModule,
        fundConfig.managementFee,
        fundConfig.performanceFee,
        fundConfig.rebalanceInterval,
        fundConfig.weightTolerance,
        fundConfig.salt
    );

    console.log("Computed fund address:", computedAddress);

    // Deploy the fund
    console.log("\n🚀 Deploying fund...");
    const tx = await fundFactory.createFund(
        fundConfig.name,
        fundConfig.symbol,
        fundConfig.manager,
        fundConfig.allowedAssets,
        fundConfig.targetWeights,
        fundConfig.priceOracle,
        fundConfig.dexRouter,
        fundConfig.feeCollector,
        fundConfig.rebalanceValidator,
        fundConfig.emergencyModule,
        fundConfig.managementFee,
        fundConfig.performanceFee,
        fundConfig.rebalanceInterval,
        fundConfig.weightTolerance,
        fundConfig.salt
    );

    console.log("Transaction hash:", tx.hash);
    console.log("⏳ Waiting for confirmation...");
    await tx.wait();
    console.log("✅ Fund deployed successfully!");

    // === PHASE 4: Verification ===

    console.log("\n🔍 PHASE 4: Verification\n");

    // Verify the fund was created
    const funds = await fundFactory.getFundsByManager(deployer.address);
    console.log("Manager's funds:", funds);

    const fundContract = await ethers.getContractAt("TradCemFund", computedAddress);

    console.log("\n📊 Fund Details:");
    console.log("- Address:", computedAddress);
    console.log("- Name:", await fundContract.name());
    console.log("- Symbol:", await fundContract.symbol());
    console.log("- Manager:", await fundContract.manager());
    console.log("- Total Supply:", (await fundContract.totalSupply()).toString());
    console.log("- NAV:", (await fundContract.calculateNAV()).toString());

    // === PHASE 5: Save Deployment Info ===

    console.log("\n💾 PHASE 5: Saving Deployment Info\n");

    const deploymentInfo = {
        network: "bscTestnet",
        deployer: deployer.address,
        timestamp: new Date().toISOString(),
        contracts: deployedContracts,
        supportedAssets: ASSETS,
        funds: [{
            name: fundConfig.name,
            symbol: fundConfig.symbol,
            address: computedAddress,
            createdAt: new Date().toISOString(),
            config: fundConfig
        }]
    };

    // Create deployments directory if it doesn't exist
    if (!fs.existsSync('./deployments')) {
        fs.mkdirSync('./deployments');
    }

    fs.writeFileSync('./deployments/testnet.json', JSON.stringify(deploymentInfo, null, 2));
    console.log("✅ Deployment info saved to deployments/testnet.json");

    // === FINAL SUMMARY ===

    console.log("\n🎉 DEPLOYMENT COMPLETE!");
    console.log("═══════════════════════════════════════════════════════════════");
    console.log("📋 Contract Addresses:");
    Object.entries(deployedContracts).forEach(([name, address]) => {
        console.log(`   ${name}: ${address}`);
    });
    console.log(`   Fund: ${computedAddress}`);
    console.log("\n💡 Next Steps:");
    console.log("1. Get BUSD from faucet: https://testnet.binance.org/faucet-smart");
    console.log("2. Test deposit: fund.deposit(amount)");
    console.log("3. Test rebalance: fund.rebalance() (as manager)");
    console.log("4. Test withdrawal: fund.redeem(shares)");
    console.log("\n🔗 View on BscScan:");
    console.log(`   https://testnet.bscscan.com/address/${computedAddress}`);
    console.log("═══════════════════════════════════════════════════════════════");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Deployment failed:", error);
        process.exit(1);
    });