const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  
  const LucasToken = await hre.ethers.getContractFactory("LucasToken");
  const token = await LucasToken.deploy(deployer.address);
  
  // For newer Hardhat/ethers versions:
  await token.waitForDeployment(); // Instead of token.deployed()
  
  // Get the deployed contract address
  const tokenAddress = await token.getAddress(); // Instead of token.address
  
  console.log("LucasToken deployed to:", tokenAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});