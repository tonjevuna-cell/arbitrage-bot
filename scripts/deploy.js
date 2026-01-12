const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  const Arbitrage = await hre.ethers.getContractFactory("Arbitrage");

  const flashLoanProviderAddress = "0xFLASHLOAN_PROVIDER_ADDRESS";
  const router1Address = "0xDEX1_ROUTER_ADDRESS";
  const router2Address = "0xDEX2_ROUTER_ADDRESS";

  const arbitrage = await Arbitrage.deploy(flashLoanProviderAddress, router1Address, router2Address);
  await arbitrage.deployed();

  console.log("Arbitrage contract deployed to:", arbitrage.address);
}

main().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});
