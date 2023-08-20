require("@nomicfoundation/hardhat-toolbox");
// require("@nomiclabs/hardhat-ethers");
// require("@nomiclabs/hardhat-etherscan");
// require("@nomiclabs/hardhat-waffle");
//You need this one if eth is not found
// require("@nomiclabs/hardhat-web3");
// require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */

const METAMASK_PRIVATE_KEY = '059ee1eee884a06b4e31c8928ee13973d175ac5d84da9161c1cdced78fe2eae6'
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.8",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }    
    ]
  },
  contractSizer: {
    alphaSort: false,
    runOnCompile: true,
    disambiguatePaths: false,
  },
  etherscan: {//
    // apiKey:{
    //   bsc:'2QSKIII1NMIYKBXQHEPM7U2W5QZRPRU2HY',
    //   core:'ddf61ebf7c8e4fb69f6801780a2ae484',
    //   eth:'Y9S87DI4YVCQKW3JV32CBG3J4BRAY52ICW'
    // }
    apiKey:'Y9S87DI4YVCQKW3JV32CBG3J4BRAY52ICW'
  },
  networks: {
    bsc: {
      chainId: 56,
      url: `https://bsc-dataseed1.binance.org`,
      //			url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_API}`,
      accounts: [`0x${METAMASK_PRIVATE_KEY}`],
      //		gas: 7000000,
      skipDryRun: true,
    },
    eth: {
      chainId: 1,
      url: `https://mainnet.infura.io/v3/5a22d0083e05498383fefc663221a06c`,
      //			url: `https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_API}`,
      accounts: [`0x${METAMASK_PRIVATE_KEY}`],
      //		gas: 7000000,
      skipDryRun: true,
    },
  }
  
};
