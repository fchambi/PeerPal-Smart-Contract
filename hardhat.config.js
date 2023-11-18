require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",   
    networks: {
      scrollSepolia: {
        url: "https://sepolia-rpc.scroll.io/" || "",
        accounts:
          process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      },
    },
    etherscan: {
      apiKey: {
        scrollSepolia: 'abc',
      },
      customChains: [
        {
          network: 'scrollSepolia',
          chainId: 534351,
          urls: {
            apiURL: 'https://sepolia-blockscout.scroll.io/api',
            browserURL: 'https://sepolia-blockscout.scroll.io/',
          },
        },
      ],
    },
  
};

