import { ethers } from 'hardhat';
import dotenv from 'dotenv';
dotenv.config();

async function main() {
  const network = await ethers.provider.getNetwork();
  const accounts = await ethers.getSigners();

  const ownerAddress = await accounts[0].getAddress();
  const safeAddress = process.env.SAFE_ADDRESS || "0x2C4B9a7820EeF6CcA975B908B446Bcfa197CF23A";

  console.log(`Deploying to network: ${network.name} (${network.chainId})`);
  console.log(`Owner address: ${ownerAddress}`);
  console.log(`Safe address: ${safeAddress}`);

  const safeGovernance = await ethers.deployContract("SafeGovernance", [safeAddress, ownerAddress], {
    deterministicDeployment: process.env.DETERMINISTIC_DEPLOYMENT || false
  });

  await safeGovernance.waitForDeployment();
  console.log(`SafeGovernance deployed to: ${safeGovernance.target}`);

  // --- Examples ---
  const sendModule = await ethers.deployContract("SendModule", [safeAddress, safeGovernance.target], {
    deterministicDeployment: process.env.DETERMINISTIC_DEPLOYMENT || false
  });

  await sendModule.waitForDeployment();
  console.log(`SendModule deployed to: ${sendModule.target}`);

  const ownableSendModule = await ethers.deployContract("OwnableSendModule", [safeAddress, ownerAddress], {
    deterministicDeployment: process.env.DETERMINISTIC_DEPLOYMENT || false
  });

  await ownableSendModule.waitForDeployment();
  console.log(`OwnableSendModule deployed to: ${ownableSendModule.target}`);

  const uniswapV2Manager = await ethers.deployContract("UniswapV2Manager", [
    safeAddress,
    safeGovernance.target,
    "0x9A676e781A523b5d0C0e43731313A708CB607508", // (address) feeToSetter
    "0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82" // (address) feeTo
  ], {
    deterministicDeployment: process.env.DETERMINISTIC_DEPLOYMENT || false
  });

  await uniswapV2Manager.waitForDeployment();
  console.log(`UniswapV2Manager deployed to: ${uniswapV2Manager.target}`);
};

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
