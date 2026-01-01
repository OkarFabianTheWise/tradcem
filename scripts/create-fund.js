const { ethers } = require("hardhat");
const fs = require('fs');

async function main() {
    console.log("🏗️ Creating sample TradCem fund...\n");

    const [deployer] = await ethers.getSigners();
    console.log("Creating fund with account:", deployer.address);

    // Load deployment addresses from file
    let deploymentInfo;
    try {
        deploymentInfo = JSON.parse(fs.readFileSync('./deployments/testnet.json', 'utf8'));
        console.log("✅ Loaded deployment info from deployments/testnet.json");
    } catch (error) {
        console.error("❌ Could not load deployment info. Please run 'npm run deploy:testnet' first.");
        process.exit(1);
    }

    const DEPLOYMENT_ADDRESSES = deploymentInfo.contracts;

    // Asset addresses on BSC Testnet
    const ASSETS = deploymentInfo.supportedAssets;

    console.log("Using deployed contracts:");
    Object.entries(DEPLOYMENT_ADDRESSES).forEach(([name, address]) => {
        console.log(`- ${name}: ${address}`);
    });

    const fundFactory = await ethers.getContractAt("FundFactory", DEPLOYMENT_ADDRESSES.fundFactory);

    // Sample fund configuration
    const fundConfig = {
        name: "TradCem Balanced Fund",
        symbol: "TCBF",
        manager: deployer.address,
        allowedAssets: [ASSETS.BUSD, ASSETS.WBNB, ASSETS.CAKE],
        targetWeights: [5000, 3000, 2000], // 50% BUSD, 30% WBNB, 20% CAKE
        priceOracle: DEPLOYMENT_ADDRESSES.priceOracle,
        dexRouter: DEPLOYMENT_ADDRESSES.dexRouter,
        feeCollector: DEPLOYMENT_ADDRESSES.feeCollector,
        rebalanceValidator: DEPLOYMENT_ADDRESSES.rebalanceValidator,
        emergencyModule: DEPLOYMENT_ADDRESSES.emergencyModule,
        managementFee: 200, // 2%
        performanceFee: 2000, // 20%
        rebalanceInterval: 7 * 24 * 60 * 60, // 7 days
        weightTolerance: 500, // 5%
        salt: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("tradcem-balanced-fund-v1")),
    };

    console.log("\n📋 Fund Configuration:");
    console.log("- Name:", fundConfig.name);
    console.log("- Symbol:", fundConfig.symbol);
    console.log("- Assets:", fundConfig.allowedAssets);
    console.log("- Weights:", fundConfig.targetWeights.map(w => w / 100 + "%"));
    console.log("- Management Fee:", fundConfig.managementFee / 100 + "%");
    console.log("- Performance Fee:", fundConfig.performanceFee / 100 + "%");

    // Compute fund address before deployment
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

    // Update deployment info with fund address
    deploymentInfo.funds = deploymentInfo.funds || [];
    deploymentInfo.funds.push({
        name: fundConfig.name,
        symbol: fundConfig.symbol,
        address: computedAddress,
        createdAt: new Date().toISOString(),
        config: fundConfig
    });

    fs.writeFileSync('./deployments/testnet.json', JSON.stringify(deploymentInfo, null, 2));
    console.log("💾 Updated deployment info with fund address");

    console.log("\n🎉 Sample fund creation complete!");
    console.log("📋 Fund Address:", computedAddress);
    console.log("\n💡 Next steps:");
    console.log("1. Get some BUSD from faucet: https://testnet.binance.org/faucet-smart");
    console.log("2. Approve BUSD spending: await busd.approve(fundAddress, amount)");
    console.log("3. Deposit to fund: await fund.deposit(amount)");
    console.log("4. Test rebalancing: await fund.rebalance() (as manager)");
    console.log("5. Withdraw shares: await fund.redeem(shares)");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Fund creation failed:", error);
        process.exit(1);
    });