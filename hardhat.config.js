require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    optimism: {
      url: "https://mainnet.optimism.io",
    },
  },

  solidity: {
    version: "0.8.9",
  },
};
