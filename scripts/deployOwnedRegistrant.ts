import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

export interface IDeployOwnedRegistrantParams {
  newowner: string;
}

export const deployOwnedRegistrant = async (
  args: IDeployOwnedRegistrantParams,
  hre: HardhatRuntimeEnvironment,
) => {
  // Compile again in case we have a coverage build (binary too large to deploy)
  await hre.run('compile');
  const contractName = 'OwnedRegistrant';

  const OwnedRegistrant = await hre.ethers.getContractFactory(contractName);

  const params = [args.newowner] as const;

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

  const contract = await OwnedRegistrant.deploy(...params);

  await contract.deployed();

  console.log(`${contractName} deployed to:`, contract.address);
};
