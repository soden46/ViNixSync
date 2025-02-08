const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function deployContract(name, constructorArgs = []) {
  console.log(`🚀 Deploying ${name}...`);

  try {
    const Contract = await hre.ethers.getContractFactory(name);
    const contract = await Contract.deploy(...constructorArgs);

    console.log(`⏳ Waiting for ${name} deployment...`);
    await contract.waitForDeployment();

    const contractAddress = await contract.getAddress();
    console.log(`✅ ${name} deployed at: ${contractAddress}`);

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
    // Deploy AIOracle
    const aiOracle = await deployContract("AIOracle");

    // Deploy HybridChain with the correct parameters
    const baseTransactionFee = hre.ethers.parseEther("0.00001");
    const minimumStake = hre.ethers.parseEther("0.001");

    const hybridChain = await deployContract("HybridChain", [
      aiOracle.target, // Use .target for the contract address
      baseTransactionFee,
      minimumStake,
    ]);

    // Deploy ValidatorReward with all necessary arguments
    const validatorReward = await deployContract("ValidatorReward", [
      hybridChain.target, // Address of HybridChain
      hre.ethers.parseEther("0.000001"), // baseRewardPerValidation
      100, // reputationMultiplier
      10, // powBonusMultiplier
      5,  // pohBonusMultiplier
      20, // aiPerformanceMultiplier
      50, // minimumReputationScore
      60, // minimumAIAccuracyScore
      86400, // distributionCooldown (1 day in seconds)
    ]);

    // Deploy ViNixSyncToken
    const viNixSyncToken = await deployContract("ViNixSyncToken", [aiOracle.target]);

    // Save deployed contract addresses to a file
    const deployments = {
      AIOracle: await aiOracle.getAddress(),
      HybridChain: await hybridChain.getAddress(),
      ValidatorReward: await validatorReward.getAddress(),
      ViNixSyncToken: await viNixSyncToken.getAddress(),
    };

    const filePath = path.join(__dirname, "deployments.json");
    fs.writeFileSync(filePath, JSON.stringify(deployments, null, 2));
    console.log("✅ Deployments saved to:", filePath);

    // Verify contracts (if needed)
    if (hre.network.name !== "hardhat") {
      console.log("🔍 Verifying contracts...");
      try {
        await hre.run("verify:verify", {
          address: await aiOracle.getAddress(),
          constructorArguments: [],
        });
        await hre.run("verify:verify", {
          address: await hybridChain.getAddress(),
          constructorArguments: [
            await aiOracle.getAddress(),
            baseTransactionFee,
            minimumStake,
          ],
        });
        await hre.run("verify:verify", {
          address: await validatorReward.getAddress(),
          constructorArguments: [
            await hybridChain.getAddress(),
            hre.ethers.parseEther("0.000001"),
            100,
            10,
            5,
            20,
            50,
            60,
            86400,
          ],
        });
        await hre.run("verify:verify", {
          address: await viNixSyncToken.getAddress(),
          constructorArguments: [],
        });
        console.log("✅ Contracts verified!");
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
