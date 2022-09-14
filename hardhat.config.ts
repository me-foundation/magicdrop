import 'dotenv/config';

import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-gas-reporter';
import 'hardhat-watcher';
import { HardhatUserConfig, task, types } from 'hardhat/config';
import 'solidity-coverage';

import { setActiveStage } from './scripts/setActiveStage';
import { setStages } from './scripts/setStages';
import { setPaused } from './scripts/setPaused';
import { deploy } from './scripts/deploy';
// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.7',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    artifacts: './artifacts',
    cache: './cache',
    sources: './contracts',
    tests: './test',
  },
  networks: {
    ropsten: {
      url: process.env.ROPSTEN_URL || '',
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    goerli: {
      url:
        process.env.GOERLI_URL ||
        'https://eth-goerli.g.alchemy.com/v2/BEZDQ5_tnBzef79wuWRQWjK4gqPlhXqK',
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: 'USD',
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

task('setStages', 'Set stages for ERC721M')
  .addParam('contract', 'contract address')
  .addParam('stages', 'stages json file')
  .setAction(setStages);

task('setActiveStage', 'Set active stage for ERC721M')
  .addParam('contract', 'contract address')
  .addParam('stage', 'stage index to set to active')
  .setAction(setActiveStage);

task('setPaused', 'Set paused state for ERC721M')
  .addParam('contract', 'contract address')
  .addParam('paused', 'paused state', 'true', types.boolean)
  .setAction(setPaused);

task('deploy', 'Deploy ERC721M')
  .addParam('name', 'name')
  .addParam('symbol', 'symbol')
  .addParam('maxsupply', 'max supply')
  .addParam('globalwalletlimit', 'global wallet limit')
  .setAction(deploy);

export default config;
