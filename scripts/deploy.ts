// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from './common/constants';

export interface IDeployParams {
  name: string;
  symbol: string;
  tokenurisuffix: string;
  maxsupply: string;
  globalwalletlimit: string;
  cosigner?: string;
  timestampexpiryseconds?: number;
  increasesupply?: boolean;
  useoperatorfilterer?: boolean;
  openedition?: boolean;
  autoapproveaddress?: string;
  pausable?: boolean;
  mintcurrency?: string;
  useerc721c?: boolean;
  useerc2198?: boolean;
  erc2198royaltyreceiver?: string,
  erc2198royaltyfeenumerator?: number,
}

export const deploy = async (
  args: IDeployParams,
  hre: HardhatRuntimeEnvironment,
) => {
  // Compile again in case we have a coverage build (binary too large to deploy)
  await hre.run('compile');
  let contractName: string = ContractDetails.ERC721M.name;

  if (args.useerc721c && args.useerc2198) {
    contractName = ContractDetails.ERC721CMBasicRoyalties.name;
  } else if (args.useerc721c) {
    contractName = ContractDetails.ERC721CM.name;
  } else if (args.useoperatorfilterer) {
    if (args.increasesupply) {
      contractName = ContractDetails.ERC721MIncreasableOperatorFilterer.name;
    } else if (args.autoapproveaddress) {
      contractName = ContractDetails.ERC721MOperatorFiltererAutoApprover.name;
    } else if (args.pausable) {
      contractName = ContractDetails.ERC721MPausableOperatorFilterer.name;
    } else {
      contractName = ContractDetails.ERC721MOperatorFilterer.name;
    }
  } else {
    if (args.increasesupply) {
      contractName = ContractDetails.ERC721MIncreasableSupply.name;
    } else if (args.autoapproveaddress) {
      contractName = ContractDetails.ERC721MAutoApprover.name;
    } else if (args.pausable) {
      contractName = ContractDetails.ERC721MPausable.name;
    }
  }

  let maxsupply = hre.ethers.BigNumber.from(args.maxsupply);

  if (args.openedition) {
    maxsupply = hre.ethers.BigNumber.from('999999999');
  }

  console.log(
    `Going to deploy ${contractName} with params`,
    JSON.stringify(args, null, 2),
  );

  const contractFactory = await hre.ethers.getContractFactory(contractName);

  const params = [
    args.name,
    args.symbol,
    args.tokenurisuffix,
    maxsupply,
    hre.ethers.BigNumber.from(args.globalwalletlimit),
    args.cosigner ?? hre.ethers.constants.AddressZero,
    args.timestampexpiryseconds ?? 300,
    args.mintcurrency ?? hre.ethers.constants.AddressZero,
  ] as any[];

  if (args.autoapproveaddress) {
    params.push(args.autoapproveaddress);
  }

  if (args.useerc2198) {
    params.push(
      args.erc2198royaltyreceiver ?? hre.ethers.constants.AddressZero,
      args.erc2198royaltyfeenumerator ?? 0,
    );
  }

  console.log(
    `Constructor params: `,
    JSON.stringify(
      params.map((param) => {
        if (hre.ethers.BigNumber.isBigNumber(param)) {
          return param.toString();
        }
        return param;
      }),
    ),
  );

  if (!(await confirm({ message: 'Continue to deploy?' }))) return;

  const contract = await contractFactory.deploy(...params);

  await contract.deployed();

  console.log(`${contractName} deployed to:`, contract.address);
};
