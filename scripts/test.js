const hre = require("hardhat");

async function deployContract(name, constructorArgs = []) {
  console.log(`🚀 Deploying ${name}...`);

  try {
    const Contract = await hre.ethers.getContractFactory(name);
    const contract = await Contract.deploy(...constructorArgs);

    console.log(`⏳ Waiting for ${name} deployment...`);

    // Ensure deployTransaction exists and wait for it to be mined
    if (contract.deployTransaction) {
      await contract.deployTransaction.wait();
    } else {
      throw new Error(`Deploy transaction not found for ${name}`);
    }

    console.log(`✅ ${name} deployed at: ${contract.address}`);
    return contract;
  } catch (error) {
    console.error(`❌ Failed to deploy ${name}:`, error.message);
    throw error;
  }
}

async function main() {
  console.log("======================================");
  console.log("🚀 Starting contract tests...");
  console.log("======================================");

  try {
    // Deploy AIOracle contract
    const aiOracle = await deployContract("AIOracle");
    console.log(`AIOracle deployed at: ${aiOracle.address}`);

    // Set values for the transaction fee and minimum stake
    const baseTransactionFee = 1000; // Replace with your desired value (e.g., in wei)
    const minimumStake = 0;       // Replace with your desired value (e.g., in wei)

    // Deploy HybridChain contract with AIOracle address, baseTransactionFee, and minimumStake
    const hybridChain = await deployContract("HybridChain", [aiOracle.address, baseTransactionFee, minimumStake]);
    console.log(`HybridChain deployed at: ${hybridChain.address}`);

    // Deploy ValidatorReward contract
    const validatorReward = await deployContract("ValidatorReward", [hybridChain.address]);
    console.log(`ValidatorReward deployed at: ${validatorReward.address}`);

    console.log("🎉 All contracts deployed successfully!");

  } catch (error) {
    console.error("❌ Test failed:", error);
    process.exitCode = 1;
  }
}

main();
