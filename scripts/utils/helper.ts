import fs from 'fs';
import path from 'path';
import { confirm } from '@inquirer/prompts';
import { Deferrable, getAddress, isAddress } from 'ethers/lib/utils';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TransactionRequest } from '@ethersproject/abstract-provider';
import * as child from 'child_process';
import { BigNumber, Overrides } from 'ethers';

const gasPricePctDiffAlert = 20; // Set threshold to alert when attempting to under/overpay against the current gas price median by X% (e.g. 20 = 20%)

export const checkCodeVersion = async () => {
  const localLatestCommit = child
    .execSync('git rev-parse HEAD')
    .toString()
    .trim();
  const remoteLatestCommit = child
    .execSync(
      "git ls-remote https://github.com/me-foundation/magicdrop.git HEAD | awk '{ print $1}'",
    )
    .toString()
    .trim();
  console.log('local latest commit:\t', localLatestCommit);
  console.log('remote latest commit:\t', remoteLatestCommit);

  if (localLatestCommit !== remoteLatestCommit) {
    console.log(
      '🟡 Warning: you are NOT using the latest version of the code. Please run `git pull` on main branch to update the code. Then run `npm run clean && npm run install && npm run build`',
    );
    if (!(await confirm({ message: 'Proceed anyway?', default: false }))) {
      return false;
    }
  }
  return true;
};

export const estimateGas = async (
  hre: HardhatRuntimeEnvironment,
  tx: Deferrable<TransactionRequest>,
  overrides?: Overrides,
) => {
  const overrideGasLimit = overrides?.gasLimit as BigNumber;
  const overrideGasPrice = overrides?.gasPrice as BigNumber;
  const estimatedGasUnit = await hre.ethers.provider.estimateGas(tx);
  const estimatedGasPrice = await hre.ethers.provider.getGasPrice();
  const estimatedGasCost = estimatedGasUnit.mul(
    overrideGasPrice ?? estimatedGasPrice,
  );
  if (overrideGasLimit && overrideGasLimit < estimatedGasUnit) {
    const diffPct =
      (estimatedGasUnit.toNumber() / overrideGasLimit.toNumber() - 1) * 100;
    console.log(
      '\x1b[31m[WARNING]\x1b[0m Estimated gas units required exceeds the limit set:',
      `\x1b[33m${estimatedGasUnit.toNumber().toLocaleString()}\x1b[0m`,
      `(${
        diffPct > 0 ? '+' + diffPct.toFixed(2) : diffPct.toFixed(2)
      }% to the --gaslimit \x1b[33m${overrideGasLimit
        .toNumber()
        .toLocaleString()}\x1b[0m)`,
    );
    if (
      !(await confirm({
        message: 'There is higher probability of failure. Continue?',
      }))
    )
      return null;
  } else
    console.log(
      'Estimated gas unit:',
      `\x1b[33m${estimatedGasUnit.toNumber().toLocaleString()}\x1b[0m`,
    );

  const estimatedGasPriceFormat = estimatedGasPrice.div(1e9).toNumber();
  const overrideGasPriceFormat = overrideGasPrice
    ? overrideGasPrice.div(1e9).toNumber()
    : null;
  if (
    overrideGasPriceFormat &&
    overrideGasPriceFormat !== estimatedGasPriceFormat
  ) {
    const diffPct =
      (overrideGasPriceFormat / estimatedGasPriceFormat - 1) * 100;
    console.log(
      '\x1b[31m[WARNING]\x1b[0m Override gas price set (GWEI):',
      overrideGasPriceFormat,
      `(${
        diffPct > 0 ? '+' + diffPct.toFixed(2) : diffPct.toFixed(2)
      }% to estimated gas price`,
      estimatedGasPriceFormat,
      `)`,
    );
    if (Math.abs(diffPct) > gasPricePctDiffAlert) {
      const aboveOrBelow = diffPct > 0 ? 'ABOVE' : 'BELOW';
      if (
        !(await confirm({
          message: `You are attempting to pay more than ${gasPricePctDiffAlert}% ${aboveOrBelow} estimated gas price. Continue?`,
        }))
      )
        return null;
    }
  } else console.log('Estimated gas price (GWEI):', estimatedGasPriceFormat);

  console.log(
    `Estimated gas cost (${getTokenName(hre)}):`,
    `\x1b[33m${hre.ethers.utils.formatEther(estimatedGasCost)}\x1b[0m`,
  );

  return estimatedGasCost;
};

const getTokenName = (hre: HardhatRuntimeEnvironment) => {
  switch (hre.network.name) {
    case 'base':
    case 'mainnet':
    case 'sepolia':
    case 'goerli':
      return 'ETH';
    case 'polygon':
    case 'mumbai':
      return 'MATIC';
    case 'apechain':
      return 'APE';
    case 'arbitrum':
      return 'ARB';
    default:
      return 'ETH';
  }
};

export const cleanVariableWalletLimit = async (variableWalletLimitPath: string, writeToFile: boolean) => {
  console.log(`=========================================`);
  console.log(`Cleaning variable wallet limit file: ${variableWalletLimitPath}`);
  const file = fs.readFileSync(variableWalletLimitPath, 'utf-8');
  const walletsWithLimit = new Map<string, number>();
  let invalidNum = 0;

  file
    .split('\n')
    .filter((line) => line)
    .forEach((line) => {
      const [addressStr, limitStr] = line.split(',');

      if (!isAddress(addressStr.trim().toLowerCase())) {
        console.log(`Ignored invalid address: ${addressStr}`);
        invalidNum++;
        return;
      }
      const address = getAddress(
        addressStr.trim().toLowerCase(),
      );
      const limit = parseInt(limitStr, 10);

      if (!Number.isInteger(limit)) {
        console.log(`Ignored invalid limit for address: ${addressStr}`);
        invalidNum++;
        return;
      }
      walletsWithLimit.set(address, (walletsWithLimit.get(address) ?? 0) + limit)
    });

  console.log(`Cleaned whitelist:\t${walletsWithLimit.size}`);
  console.log(`Invalid entries:\t${invalidNum}`);

  if (writeToFile) {
    const fileName = path.basename(variableWalletLimitPath);
    const cleanedFileName = `cleaned-${fileName}`;
    fs.closeSync(fs.openSync(cleanedFileName, 'w'));

    for (const [address, limit] of walletsWithLimit.entries()) {
      fs.appendFileSync(cleanedFileName, `${address},${limit}\n`);
    }
    console.log(`Cleaned file: ${cleanedFileName}`);
  }
  console.log(`=========================================`);
  return walletsWithLimit;
}

export const cleanWhitelist = async (whitelistPath: string, writeToFile: boolean) => {
  console.log(`=========================================`);
  console.log(`Cleaning whitelist file: ${whitelistPath}`);

  let invalidNum = 0;
  const whitelist = JSON.parse(
    fs.readFileSync(whitelistPath, 'utf-8'),
  );
  const wallets = new Set<string>();

  whitelist.forEach((address: string) => {
    if (!isAddress(address)) {
      console.log(`Ignored invalid address: ${address}`);
      invalidNum++;
      return;
    }
    wallets.add(getAddress(address))
  });

  console.log(`Cleaned whitelist:\t${wallets.size}`);
  console.log(`Invalid addresses:\t${invalidNum}`);

  if (writeToFile) {
    const fileName = path.basename(whitelistPath);
    const cleanedFileName = `cleaned-${fileName}`;

    fs.writeFileSync(
      cleanedFileName,
      JSON.stringify(Array.from(wallets.values()), null, 2),
    );
    console.log(`Cleaned file: ${cleanedFileName}`);
  }
  console.log(`=========================================`);
  return wallets;
}

export const ensureArray = (value: any) => Array.isArray(value) ? value : [value];