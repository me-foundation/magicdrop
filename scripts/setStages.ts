import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { MerkleTree } from 'merkletreejs';
import fs from 'fs';
import { ContractDetails } from './common/constants';
import { estimateGas } from './utils/helper';
import { Overrides } from 'ethers';

export interface ISetStagesParams {
  stages: string;
  contract: string;
  gaspricegwei?: number;
  gaslimit?: number;
}

interface StageConfig {
  price: string;
  startDate: number;
  endDate: number;
  walletLimit?: number;
  maxSupply?: number;
  whitelistPath?: string;
  variableWalletLimitPath?: string;
}

export const setStages = async (
  args: ISetStagesParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const stagesConfig = JSON.parse(
    fs.readFileSync(args.stages, 'utf-8'),
  ) as StageConfig[];

  const ERC721M = await ethers.getContractFactory(ContractDetails.ERC721M.name);
  const contract = ERC721M.attach(args.contract);

  const overrides: Overrides = {};
  if (args.gaspricegwei) {
    overrides.gasPrice = ethers.BigNumber.from(args.gaspricegwei * 1e9);
  }
  if (args.gaslimit) {
    overrides.gasLimit = ethers.BigNumber.from(args.gaslimit);
  }

  /*
   * Merkle root generation logic:
   * - for `whitelist`, leaves are `solidityKeccak256(['address', 'uint32'], [address, 0])`
   * - for `variable wallet limit list`, leaves are `solidityKeccak256(['address', 'uint32'], [address, limit])`
   */
  const merkleRoots = await Promise.all(
    stagesConfig.map((stage) => {
      if (stage.whitelistPath) {
        const whitelist = JSON.parse(
          fs.readFileSync(stage.whitelistPath, 'utf-8'),
        );

        // Clean up whitelist
        const filteredWhitelist = whitelist.filter((address: string) =>
          ethers.utils.isAddress(address),
        );
        console.log(
          `Filtered whitelist: ${filteredWhitelist.length} addresses. ${whitelist.length - filteredWhitelist.length} invalid addresses removed.`,
        );
        const invalidWhitelist = whitelist.filter(
          (address: string) => !ethers.utils.isAddress(address),
        );
        console.log(
          `❌ Invalid whitelist: ${invalidWhitelist.length} addresses.\r\n${invalidWhitelist.join(', \r\n')}`,
        );

        if (invalidWhitelist.length > 0) {
          console.log(`🔄 🚨 updating whitelist file: ${stage.whitelistPath}`);
          fs.writeFileSync(
            stage.whitelistPath,
            JSON.stringify(filteredWhitelist, null, 2),
          );
        }

        const mt = new MerkleTree(
          filteredWhitelist.map((address: string) =>
            ethers.utils.solidityKeccak256(
              ['address', 'uint32'],
              [ethers.utils.getAddress(address), 0],
            ),
          ),
          ethers.utils.keccak256,
          {
            sortPairs: true,
            hashLeaves: true,
          },
        );
        return mt.getHexRoot();
      } else if (stage.variableWalletLimitPath) {
        const leaves: any[] = [];
        const file = fs.readFileSync(stage.variableWalletLimitPath, 'utf-8');
        file
          .split('\n')
          .filter((line) => line)
          .forEach((line) => {
            const [addressStr, limitStr] = line.split(',');

            if (!ethers.utils.isAddress(addressStr.trim().toLowerCase())) {
              console.log(`Ignored invalid address: ${addressStr}`);
              return;
            }

            const address = ethers.utils.getAddress(
              addressStr.trim().toLowerCase(),
            );
            const limit = parseInt(limitStr, 10);

            if (!Number.isInteger(limit)) {
              console.log(`Ignored invalid limit for address: ${addressStr}`);
              return;
            }

            const digest = ethers.utils.solidityKeccak256(
              ['address', 'uint32'],
              [address, limit],
            );
            leaves.push(digest);
          });

        const mt = new MerkleTree(leaves, ethers.utils.keccak256, {
          sortPairs: true,
          hashLeaves: false,
        });
        return mt.getHexRoot();
      }

      return ethers.utils.hexZeroPad('0x', 32);
    }),
  );

  const stages = stagesConfig.map((s, i) => ({
    price: ethers.utils.parseEther(s.price),
    maxStageSupply: s.maxSupply ?? 0,
    walletLimit: s.walletLimit ?? 0,
    merkleRoot: merkleRoots[i],
    startTimeUnixSeconds: Math.floor(new Date(s.startDate).getTime() / 1000),
    endTimeUnixSeconds: Math.floor(new Date(s.endDate).getTime() / 1000),
  }));

  console.log(
    `Stage params: `,
    JSON.stringify(
      stages.map((stage) =>
        hre.ethers.BigNumber.isBigNumber(stage) ? stage.toString() : stage,
      ),
    ),
  );

  const tx = await contract.populateTransaction.setStages(stages);
  if (!(await estimateGas(hre, tx, overrides))) return;

  if (!(await confirm({ message: 'Continue to set stages?' }))) return;

  const submittedTx = await contract.setStages(stages, overrides);

  console.log(`Submitted tx ${submittedTx.hash}`);
  await submittedTx.wait();
  console.log('Stages set');

  for (let i = 0; i < stagesConfig.length; i++) {
    const [stage] = await contract.getStageInfo(i);
    console.log(`Stage ${i} info: ${stage}`);
  }
};
