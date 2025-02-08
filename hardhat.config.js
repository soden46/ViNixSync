require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();

module.exports = {
  solidity: "0.8.20",
  networks: {
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
      gasPrice: 52000000000, // 51 Gwei
      gas: 3000000,
    },
    holesky: {
      url: `https://eth-holesky.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
    },
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHER_SCAN_API_KEY,  // Use Etherscan API key for Sepolia
      holesky: process.env.ETHER_SCAN_API_KEY,  // Use Etherscan API key for Holesky
    },
  },
};
