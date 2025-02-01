const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function deployContract(name, constructorArgs = []) {
  console.log(`🚀 Deploying ${name}...`);

  try {
    const Contract = await hre.ethers.getContractFactory(name);
    const contract = await Contract.deploy(...constructorArgs);

    console.log(`⏳ Waiting for ${name} deployment...`);
    await contract.deployTransaction.wait();  // Ensure the transaction is mined

    console.log(`✅ ${name} deployed at: ${contract.address}`);
    return contract;
  } catch (error) {
    console.error(`❌ Failed to deploy ${name}:`, error.message);
    throw error;
  }
}

async function main() {
  console.log("======================================");
  console.log("🚀 Starting contract deployments...");
  console.log("======================================");

  try {
    const aiOracle = await deployContract("AIOracle");
    const hybridChain = await deployContract("HybridChain", [aiOracle.address]);
    const validatorReward = await deployContract("ValidatorReward", [hybridChain.address]);

    const deployments = {
      AIOracle: aiOracle.address,
      HybridChain: hybridChain.address,
      ValidatorReward: validatorReward.address,
    };

    const filePath = path.join(__dirname, "deployments.json");
    fs.writeFileSync(filePath, JSON.stringify(deployments, null, 2));

    console.log("✅ Deployments saved to:", filePath);

    // Optional: Verify contracts on Etherscan (if necessary)
    if (hre.network.name !== "hardhat") {
      console.log("🔍 Verifying contracts on Etherscan...");
      try {
        await hre.run("verify:verify", {
          address: aiOracle.address,
          constructorArguments: [],
        });
        await hre.run("verify:verify", {
          address: hybridChain.address,
          constructorArguments: [aiOracle.address],
        });
        await hre.run("verify:verify", {
          address: validatorReward.address,
          constructorArguments: [hybridChain.address],
        });
        console.log("✅ Contracts verified successfully!");
      } catch (error) {
        console.warn("⚠️ Verification failed:", error.message);
      }
    }

    console.log("🎉 All contracts deployed successfully!");
  } catch (error) {
    console.error("❌ Deployment failed:", error);
    process.exitCode = 1;
  }
}

main();