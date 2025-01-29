const hre = require("hardhat");

async function main() {
  const HybridChain = await hre.ethers.getContractFactory("HybridChain");
  const hybridChain = await HybridChain.deploy();
  await hybridChain.deployed();
  console.log(`HybridChain deployed at ${hybridChain.address}`);

  const ValidatorReward = await hre.ethers.getContractFactory("ValidatorReward");
  const validatorReward = await ValidatorReward.deploy(hybridChain.address);
  await validatorReward.deployed();
  console.log(`ValidatorReward deployed at ${validatorReward.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
