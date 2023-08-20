// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
// const { utils, constants, BigNumber } = require("ethers")
// import { ethers, network, run } from "hardhat";
// const { utils, constants, BigNumber } = require("ethers")

async function main() {

  const originalBridgeFactory = await hre.ethers.getContractFactory("OriginalBridge")

  const originalBridge = await originalBridgeFactory.deploy(
    '0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675',
    153,
    '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
  )

  await originalBridge.registerToken('0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', 18)//weth
  await originalBridge.registerToken('0xdAC17F958D2ee523a2206206994597C13D831ec7', 6)//usdt

  await originalBridge.setTrustedRemoteAddress(153, '0xf9Cb6Df708f99D45CbaaEbaF58cb3F734b272683')
  console.log(originalBridge.address)

  //用来验证合约
  await hre.run(`verify:verify`, {
    address: originalBridge.address,
    constructorArguments: ['0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675',153,'0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
