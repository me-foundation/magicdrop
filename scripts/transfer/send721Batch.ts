import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ERC721BatchTransferContract } from '../common/constants';
import fs from 'fs';
import { estimateGas } from '../utils/helper';

export interface ISend721BatchParams {
  contract: string;
  transferfile?: string;
  to?: string;
  tokenids?: string;
}

export const send721Batch = async (
  args: ISend721BatchParams,
  hre: HardhatRuntimeEnvironment,
) => {
  // check if the BatchTransfer721 contract has the approval to transfer the tokens
  const [signer] = await hre.ethers.getSigners();

  const erc721Contract = (
    await hre.ethers.getContractFactory('ERC721A')
  ).attach(args.contract);
  const approved = await erc721Contract.isApprovedForAll(
    signer.address,
    ERC721BatchTransferContract,
  );
  if (!approved) {
    console.warn(
      'ERC721BatchTransfer contract is not approved to transfer tokens. Approving...',
    );
    await erc721Contract.setApprovalForAll(ERC721BatchTransferContract, true);
    console.log('Approved');
  }

  const tokenids = args.tokenids?.split(',').map((id) => parseInt(id));
  const factory = await hre.ethers.getContractFactory('ERC721BatchTransfer');
  const batchTransferContract = factory.attach(ERC721BatchTransferContract);

  if (!args.transferfile) {
    if (!args.to || !args.tokenids) {
      console.error('Missing required arguments: to, tokenIds');
      return;
    }
    const tx =
      await batchTransferContract.populateTransaction.safeBatchTransferToSingleWallet(
        args.contract,
        args.to,
        tokenids!,
      );
    await estimateGas(hre, tx);

    if (!(await confirm({ message: 'Continue to transfer?' }))) return;
    console.log(`Transferring tokens to ${args.to}...`);
    const submittedTx =
      await batchTransferContract.safeBatchTransferToSingleWallet(
        args.contract,
        args.to,
        tokenids!,
      );

    console.log(`Submitted tx ${submittedTx.hash}`);
    await submittedTx.wait();
    console.log('Tokens transferred');
  } else {
    const lines = fs
      .readFileSync(args.transferfile, 'utf-8')
      .split('\n')
      .filter(Boolean);
    const tos = [];
    const tokenIds = [];

    for (const line of lines) {
      const [to, tokenId] = line.split(' ');
      tos.push(to);
      tokenIds.push(tokenId);
    }

    if (tos.length !== tokenIds.length) {
      console.error('Invalid transfer file');
      return;
    }

    if (tos.length === 0) {
      console.error('No transfers found');
      return;
    }

    const tx =
      await batchTransferContract.populateTransaction.safeBatchTransferToMultipleWallets(
        args.contract,
        tos,
        tokenIds,
      );
    await estimateGas(hre, tx);

    if (!(await confirm({ message: 'Continue to transfer?' }))) return;

    console.log(`Transferring tokens...`);
    const submittedTx =
      await batchTransferContract.safeBatchTransferToMultipleWallets(
        args.contract,
        tos,
        tokenIds,
      );
    console.log(`Submitted tx ${submittedTx.hash}`);
    await submittedTx.wait();
    console.log('Tokens transferred');
  }
};
