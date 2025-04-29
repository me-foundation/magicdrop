import { encodeFunctionData, formatEther, Hex } from 'viem';
import { actionPresets } from './common';
import { WITHDRAW_CONTRACT_BALANCE_ABI } from '../../abis';
import { printTransactionHash, showError, showText } from '../display';
import { promptForConfirmation } from '../getters';

export const withdrawContractBalanceAction = async (collection: string) => {
  try {
    const { cm, config } = await actionPresets(collection);

    const balance = await cm.client.getBalance({
      address: config.deployment!.contract_address as Hex,
      blockTag: 'latest',
    });
    const balanceInEth = formatEther(balance);
    console.log('balanceInEth', balanceInEth);

    if (balanceInEth === '0') {
      console.log('Contract has no balance to withdraw.');
      return;
    }

    showText(
      `You're about to withdraw Contract Balance: ${balanceInEth} ETH`,
      '',
      false,
      false,
    );

    const confirm = await promptForConfirmation(
      'Do you want to withdraw the entire balance?',
    );
    if (!confirm) {
      showText('Withdrawal cancelled. Aborting...');
      return;
    }

    console.log('Withdrawing funds... this will take a moment.');
    const data = encodeFunctionData({
      abi: [WITHDRAW_CONTRACT_BALANCE_ABI],
      functionName: WITHDRAW_CONTRACT_BALANCE_ABI.name,
      args: [],
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
    showError({ text: `Failed to withdraw funds: ${error.message}` });
  }
};
