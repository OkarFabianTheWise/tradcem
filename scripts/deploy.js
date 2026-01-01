const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 Starting TradCem deployment on BNB Chain Testnet...\n");

    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    console.log("Account balance:", ethers.utils.formatEther(await deployer.getBalance()), "BNB");

    const deployedContracts = {};

    // Deploy PriceOracle first
    console.log("\n📊 Deploying PriceOracle...");
    const PriceOracle = await ethers.getContractFactory("PriceOracle");
    const priceOracle = await PriceOracle.deploy();
    await priceOracle.deployed();
    console.log("✅ PriceOracle deployed to:", priceOracle.address);
    deployedContracts.priceOracle = priceOracle.address;

    // Deploy DEXRouter
    console.log("\n🔄 Deploying DEXRouter...");
    const DEXRouter = await ethers.getContractFactory("DEXRouter");
    // PancakeSwap V3 Router on BSC Testnet
    const pancakeRouter = "0x1b81D678ffb9C0263b24A97847620C99d213eB14";
    const dexRouter = await DEXRouter.deploy(pancakeRouter, ethers.constants.AddressZero, ethers.constants.AddressZero);
    await dexRouter.deployed();
    console.log("✅ DEXRouter deployed to:", dexRouter.address);
    deployedContracts.dexRouter = dexRouter.address;

    // Deploy FeeCollector
    console.log("\n💰 Deploying FeeCollector...");
    const FeeCollector = await ethers.getContractFactory("FeeCollector");
    const feeCollector = await FeeCollector.deploy();
    await feeCollector.deployed();
    console.log("✅ FeeCollector deployed to:", feeCollector.address);
    deployedContracts.feeCollector = feeCollector.address;

    // Deploy RebalanceValidator
    console.log("\n⚖️ Deploying RebalanceValidator...");
    const RebalanceValidator = await ethers.getContractFactory("RebalanceValidator");
    const rebalanceValidator = await RebalanceValidator.deploy();
    await rebalanceValidator.deployed();
    console.log("✅ RebalanceValidator deployed to:", rebalanceValidator.address);
    deployedContracts.rebalanceValidator = rebalanceValidator.address;

    // Deploy EmergencyModule
    console.log("\n🚨 Deploying EmergencyModule...");
    const EmergencyModule = await ethers.getContractFactory("EmergencyModule");
    const emergencyModule = await EmergencyModule.deploy(deployer.address);
    await emergencyModule.deployed();
    console.log("✅ EmergencyModule deployed to:", emergencyModule.address);
    deployedContracts.emergencyModule = emergencyModule.address;

    // Deploy FundFactory
    console.log("\n🏭 Deploying FundFactory...");
    const FundFactory = await ethers.getContractFactory("FundFactory");
    const fundFactory = await FundFactory.deploy();
    await fundFactory.deployed();
    console.log("✅ FundFactory deployed to:", fundFactory.address);
    deployedContracts.fundFactory = fundFactory.address;

    // Setup PriceOracle with testnet assets
    console.log("\n⚙️ Configuring PriceOracle...");
    const busdAddress = "0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7"; // BUSD on BSC Testnet
    const wbnbAddress = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd"; // WBNB on BSC Testnet
    const cakeAddress = "0xFa60D973F7642B748046464e165A65B7323b0DEE"; // CAKE on BSC Testnet

    console.log("Adding BUSD...");
    await priceOracle.addAsset(busdAddress, ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.AddressZero);
    console.log("✅ Added BUSD to PriceOracle");

    console.log("Adding WBNB...");
    await priceOracle.addAsset(wbnbAddress, ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.AddressZero);
    console.log("✅ Added WBNB to PriceOracle");

    console.log("Adding CAKE...");
    await priceOracle.addAsset(cakeAddress, ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.AddressZero);
    console.log("✅ Added CAKE to PriceOracle");

    // Setup FeeCollector with supported tokens
    console.log("\n💰 Configuring FeeCollector...");
    console.log("Adding BUSD support...");
    await feeCollector.addSupportedToken(busdAddress);
    console.log("Adding WBNB support...");
    await feeCollector.addSupportedToken(wbnbAddress);
    console.log("✅ Added supported tokens to FeeCollector");

    console.log("\n🎉 Infrastructure deployment complete!");
    console.log("📋 Contract Addresses:");
    Object.entries(deployedContracts).forEach(([name, address]) => {
        console.log(`${name}: ${address}`);
    });

    // Save deployment info to a file
    const fs = require('fs');
    const deploymentInfo = {
        network: "bscTestnet",
        deployer: deployer.address,
        timestamp: new Date().toISOString(),
        contracts: deployedContracts,
        supportedAssets: {
            BUSD: busdAddress,
            WBNB: wbnbAddress,
            CAKE: cakeAddress,
        }
    };

    // Create deployments directory if it doesn't exist
    if (!fs.existsSync('./deployments')) {
        fs.mkdirSync('./deployments');
    }

    fs.writeFileSync('./deployments/testnet.json', JSON.stringify(deploymentInfo, null, 2));
    console.log("\n💾 Deployment info saved to deployments/testnet.json");

    return deploymentInfo;
}

main()
    .then((deploymentInfo) => {
        console.log("\n🎯 Infrastructure ready! Run 'npm run create-fund:testnet' to create your first fund.");
        process.exit(0);
    })
    .catch((error) => {
        console.error("❌ Deployment failed:", error);
        process.exit(1);
    });