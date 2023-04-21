// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
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
}

export const deploy = async (
  args: IDeployParams,
  hre: HardhatRuntimeEnvironment,
) => {
  // Compile again in case we have a coverage build (binary too large to deploy)
  await hre.run('compile');

  let contractName: string;

  if (args.increasesupply) {
    contractName = ContractDetails.ERC721MIncreasableSupply.name;
    if (args.useoperatorfilterer) {
      contractName = ContractDetails.ERC721MIncreasableOperatorFilterer.name;
    }
  } else {
    contractName = ContractDetails.ERC721M.name;
    if (args.useoperatorfilterer && args.autoapproveaddress) {
      contractName = ContractDetails.ERC721MOperatorFiltererAutoApprover.name;
    } else if (args.useoperatorfilterer) {
      contractName = ContractDetails.ERC721MOperatorFilterer.name;
    } else if (args.autoapproveaddress) {
      contractName = ContractDetails.ERC721MAutoApprover.name;
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
  const ERC721M = await hre.ethers.getContractFactory(contractName);

  const params = [
    args.name,
    args.symbol,
    args.tokenurisuffix,
    maxsupply,
    hre.ethers.BigNumber.from(args.globalwalletlimit),
    args.cosigner ?? hre.ethers.constants.AddressZero,
    args.timestampexpiryseconds ?? 300,
    args.autoapproveaddress ?? hre.ethers.constants.AddressZero,
  ] as const;

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

  const erc721M = await ERC721M.deploy(...params);

  await erc721M.deployed();

  console.log(`${contractName} deployed to:`, erc721M.address);
};
