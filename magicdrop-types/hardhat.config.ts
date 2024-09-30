import 'dotenv/config';

import "@nomicfoundation/hardhat-verify";
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-contract-sizer';
import 'hardhat-gas-reporter';
import 'hardhat-watcher';
import { HardhatUserConfig, task, types } from 'hardhat/config';
import 'solidity-coverage';

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.20',
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 20,
        details: {
          yulDetails: {
            optimizerSteps: "dhfoD[xarrscLMcCTU]uljmul",
          },
        },
      },
    },
  },
  paths: {
    artifacts: './artifacts',
    cache: './cache',
    sources: './contracts',
    tests: './test',
  },
};


export default config;
