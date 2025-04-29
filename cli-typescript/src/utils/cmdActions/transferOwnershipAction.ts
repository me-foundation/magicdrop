import { encodeFunctionData, Hex, isAddress } from 'viem';
import { actionPresets } from './common';
import { TRANSFER_OWNERSHIP_ABI } from '../../abis';
import { printTransactionHash, showError, showText } from '../display';
import { promptForConfirmation } from '../getters';

const displayOwnershipTransferWarning = (): void => {
  console.log('');
  console.log(
    '################################################################################',
  );
  console.log(
    'WARNING: This action will transfer ownership of the contract to a new owner.',
  );
  console.log("Please triple check the new owner's address before proceeding!"); // eslint-disable-line
  console.log(
    '################################################################################',
  );
  console.log('');
};

export const transferOwnershipAction = async (
  collection: string,
  {
    newOwner,
  }: {
    newOwner: Hex;
  },
) => {
  try {
    const { cm, config } = await actionPresets(collection);

    if (!isAddress(newOwner)) {
      throw new Error('New owner must be a valid address');
    }

    displayOwnershipTransferWarning();

    const confirm = await promptForConfirmation(
      `You are about to transfer ownership of ${config.name} to ${newOwner}. Do you want to proceed?`,
    );
    if (!confirm) {
      showText('Ownership transfer cancelled. Aborting...');
      return;
    }

    console.log('Transferring Ownership... this will take a moment.');
    const data = encodeFunctionData({
      abi: [TRANSFER_OWNERSHIP_ABI],
      functionName: TRANSFER_OWNERSHIP_ABI.name,
      args: [newOwner],
    });

    const txHash = await cm.sendTransaction({
      to: config.deployment!.contract_address as Hex,
      data,
    });

    const receipt = await cm.waitForTransactionReceipt(txHash);

    if (receipt.status !== 'success') {
      throw new Error('Transaction failed');
    }

    printTransactionHash(receipt.transactionHash, config.chainId);
    showText(`Ownership transferred to ${newOwner}.`);
  } catch (error: any) {
    showError({ text: `Failed to transfer owenership: ${error.message}` });
  }
};
