require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      chainId: 31337
    },
    besulocal: {
      url: "http://127.0.0.1:8545",
      gasPrice: 0,
      chainId: 10001
    }
  }
};
