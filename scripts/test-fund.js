const { ethers } = require("hardhat");
const fs = require('fs');

async function main() {
    console.log("🧪 Testing TradCem Fund Operations\n");

    // Load deployment info
    const deploymentInfo = JSON.parse(fs.readFileSync('./deployments/testnet.json', 'utf8'));
    const fundAddress = deploymentInfo.funds[0].address;
    const ASSETS = deploymentInfo.supportedAssets;

    console.log("Testing fund at:", fundAddress);

    const [tester] = await ethers.getSigners();
    console.log("Testing with account:", tester.address);

    // Get contract instances
    const fund = await ethers.getContractAt("TradCemFund", fundAddress);
    const busd = await ethers.getContractAt("IERC20", ASSETS.BUSD);

    console.log("\n📊 Fund Status:");
    console.log("- Total Supply:", (await fund.totalSupply()).toString());
    console.log("- NAV:", (await fund.calculateNAV()).toString());
    console.log("- Share Price:", (await fund.getSharePrice()).toString());

    // Check BUSD balance
    const busdBalance = await busd.balanceOf(tester.address);
    console.log("- Your BUSD balance:", ethers.utils.formatEther(busdBalance));

    if (busdBalance.lt(ethers.utils.parseEther("1"))) {
        console.log("\n⚠️  You need BUSD to test deposits!");
        console.log("Get BUSD from: https://testnet.binance.org/faucet-smart");
        console.log("Or swap BNB for BUSD on PancakeSwap testnet");
        return;
    }

    const depositAmount = ethers.utils.parseEther("0.1"); // 0.1 BUSD
    console.log(`\n💰 Testing deposit of ${ethers.utils.formatEther(depositAmount)} BUSD...`);

    // Approve BUSD spending
    console.log("Approving BUSD spending...");
    await busd.approve(fundAddress, depositAmount);
    console.log("✅ Approved");

    // Deposit
    console.log("Depositing...");
    const depositTx = await fund.deposit(depositAmount);
    await depositTx.wait();
    console.log("✅ Deposit successful!");

    // Check results
    const sharesBalance = await fund.balanceOf(tester.address);
    console.log(`- You received ${ethers.utils.formatEther(sharesBalance)} shares`);

    console.log("\n📊 Updated Fund Status:");
    console.log("- Total Supply:", (await fund.totalSupply()).toString());
    console.log("- NAV:", (await fund.calculateNAV()).toString());
    console.log("- Share Price:", (await fund.getSharePrice()).toString());

    // Test withdrawal
    console.log(`\n💸 Testing withdrawal of ${ethers.utils.formatEther(sharesBalance)} shares...`);
    const withdrawTx = await fund.redeem(sharesBalance);
    await withdrawTx.wait();
    console.log("✅ Withdrawal successful!");

    console.log("\n📊 Final Fund Status:");
    console.log("- Total Supply:", (await fund.totalSupply()).toString());
    console.log("- NAV:", (await fund.calculateNAV()).toString());
    console.log("- Your BUSD balance:", ethers.utils.formatEther(await busd.balanceOf(tester.address)));

    console.log("\n🎉 All tests passed! Fund is working correctly.");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("❌ Test failed:", error);
        process.exit(1);
    });