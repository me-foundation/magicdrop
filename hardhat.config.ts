import 'dotenv/config';

import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-gas-reporter';
import 'hardhat-watcher';
import { HardhatUserConfig, task, types } from 'hardhat/config';
import 'solidity-coverage';

import { setActiveStage } from './scripts/setActiveStage';
import { setCrossmintAddress } from './scripts/setCrossmintAddress';
import { setStages } from './scripts/setStages';
import { setMintable } from './scripts/setMintable';
import { deploy } from './scripts/deploy';
import { setBaseURI } from './scripts/setBaseURI';
import { mint } from './scripts/mint';
import { ownerMint } from './scripts/ownerMint';
import { setAuctionActive } from './scripts/setAuctionActive';
import { setGlobalWalletLimit } from './scripts/setGlobalWalletLimit';

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
      url: process.env.GOERLI_URL || '',
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

task('setMintable', 'Set mintable state for ERC721M')
  .addParam('contract', 'contract address')
  .addParam('mintable', 'mintable state', 'true', types.boolean)
  .setAction(setMintable);

task('deploy', 'Deploy the specified contract; defaults to ERC721M')
  .addParam('name', 'name')
  .addParam('symbol', 'symbol')
  .addParam('maxsupply', 'max supply')
  .addParam('tokenurisuffix', 'token uri suffix', '.json')
  .addParam('globalwalletlimit', 'global wallet limit')
  .addOptionalParam(
    'cosigner',
    'cosigner address (0x00...000 if not using cosign)',
    '0x0000000000000000000000000000000000000000',
  )
  .addOptionalParam(
    'mincontributioninwei',
    'The minimum contribution in wei required only for the AcutionBucket',
    '0',
  )
  .addOptionalParam(
    'contractname',
    'The name of the contract to initialize',
    'ERC721M',
  )
  .setAction(deploy);

task('setBaseURI', 'Set the base uri')
  .addParam('uri', 'uri')
  .addParam('contract', 'contract address')
  .setAction(setBaseURI);

task('setCrossmintAddress', 'Set crossmint address')
  .addParam('contract', 'contract address')
  .addParam('crossmintAddress', 'new crossmint address')
  .setAction(setCrossmintAddress);

task('mint', 'Mint token(s)')
  .addParam('contract', 'contract address')
  .addParam('qty', 'quantity to mint', '1')
  .setAction(mint);

task('ownerMint', 'Mint token(s) as owner')
  .addParam('contract', 'contract address')
  .addParam('qty', 'quantity to mint', '1')
  .addOptionalParam('to', 'recipient address')
  .setAction(ownerMint);

task('setGlobalWalletLimit', 'Set the global wallet limit')
  .addParam('contract', 'contract address')
  .addParam('limit', 'global wallet limit (0 for no global limit)')
  .setAction(setGlobalWalletLimit);

task(
  'setAuctionActive',
  'Re-sets the auctionActive flag; the default contract is BucketAuction',
)
  .addParam('contract', 'contract address')
  .addParam('auctionactive', 'the new value of the auctionActive flag')
  .addOptionalParam(
    'contractname',
    'The name of the contract to initialize',
    'BucketAuction',
  )
  .setAction(setAuctionActive);

export default config;
