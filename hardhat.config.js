require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    optimism: {
      url: "https://mainnet.optimism.io",
    },

    hardhat: {
      forking: {
        url: "https://opt-mainnet.g.alchemy.com/v2/n-z2yPh6ET1iUWbYOTO-UT3R5-cPCc9l",
      }
    }
  },

  solidity: {
    version: "0.8.9",
  },

  etherscan: {
    apiKey: { 
      optimisticEthereum: "JGU8Z6D131R8DY1IGNJ78AEZJ7C1EAW5K1",
    }
  },
};
