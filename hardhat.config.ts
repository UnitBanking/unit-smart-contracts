import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ethers";

export default {
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
    },
  },
  solidity: {
    version: "0.8.21",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
}