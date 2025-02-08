const hre = require("hardhat");

async function cancelTransaction() {
  // Mendapatkan signer pertama dari daftar signer yang tersedia
  const [sender] = await hre.ethers.getSigners();

  // Tentukan gas price dalam ether dan konversikan ke wei menggunakan parseEther
  const gasPriceInEther = hre.ethers.parseEther("0.000000021"); // 21 gwei = 0.000000021 ether

  const tx = {
    to: sender.address,
    value: 0,
    nonce: 15, // Gunakan nonce yang benar
    gasPrice: gasPriceInEther,
    gasLimit: 21000, // Gas limit standar
  };

  console.log("📡 Sending cancellation transaction...");

  // Kirim transaksi
  const transaction = await sender.sendTransaction(tx);
  console.log(`Transaction sent! Hash: ${transaction.hash}`);

  await transaction.wait();
  console.log("✅ Transaction confirmed!");
}

cancelTransaction()
  .then(() => console.log("Transaction cancellation complete"))
  .catch((error) => {
    console.error("Error during cancellation:", error);
  });
