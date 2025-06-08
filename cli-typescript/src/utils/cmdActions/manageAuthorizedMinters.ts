import { encodeFunctionData, Hex, isAddress } from 'viem';
import { actionPresets } from './common';
import {
  ADD_AUTHORIZED_MINTER_ABI,
  REMOVE_AUTHORIZED_MINTER_ABI,
} from '../../abis';
import { printTransactionHash, showError } from '../display';
import { collapseAddress } from '../common';

export const manageAuthorizedMintersAction = async (
  symbol: string,
  { minter, action }: { minter: Hex; action: 'add' | 'remove' },
) => {
  try {
    const { cm, config } = await actionPresets(symbol);
    if (!isAddress(minter)) {
      throw new Error('minter must be a valid address');
    }

    console.log(
      `You are about to ${action === 'add' ? 'add' : 'remove'} ${minter} as an authorized minter of ${collapseAddress(config.deployment!.contract_address as Hex)}`,
    );

    console.log(
      `${action === 'add' ? 'Adding' : 'Removing'} minter... this will take a moment.`,
    );

    const abi =
      action === 'add'
        ? ADD_AUTHORIZED_MINTER_ABI
        : REMOVE_AUTHORIZED_MINTER_ABI;
    const data = encodeFunctionData({
      abi: [abi],
      functionName: abi.name,
      args: [minter],
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
  } catch (error: any) {
    showError({ text: `Failed to ${action} minter: ${error.message}` });
  }
};
