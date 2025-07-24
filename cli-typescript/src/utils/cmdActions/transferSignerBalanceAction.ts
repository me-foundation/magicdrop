import { formatEther, Hex } from 'viem';
import { actionPresets } from './common';
import { printTransactionHash, showError, showText } from '../display';
import { collapseAddress } from '../common';
import { getSymbolFromChainId, promptForConfirmation } from '../getters';

export const transferSignerBalanceAction = async (
  symbol: string,
  params: {
    receiver: Hex;
    gasLimit: number;
  },
) => {
  try {
    const { cm, config } = await actionPresets(symbol, false);
    const currencySymbol = getSymbolFromChainId(cm.chainId);

    // Get current balance
    const balance = await cm.client.getBalance({
      address: cm.signer,
    });

    // Estimate gas for the transfer
    const gasPrice = await cm.client.getGasPrice();
    const gasLimit = BigInt(params.gasLimit);
    const gasCost = gasPrice * BigInt(gasLimit);

    if (balance <= gasCost) {
      throw new Error(
        `Insufficient balance to cover gas fees. Balance: ${formatEther(balance)} ${currencySymbol}, Gas cost: ${formatEther(gasCost)} ${currencySymbol}`,
      );
    }

    // Transfer amount = balance - gas cost
    const transferAmount = balance - gasCost;

    const confirm = await promptForConfirmation(
      `You are about to transfer all available balance: ${formatEther(balance)} ${currencySymbol} to ${collapseAddress(params.receiver)}. Do you want to proceed?`,
    );
    if (!confirm) {
      showText('Transfer cancelled. Aborting...');
      return;
    }

    showText(
      `Transferring all available balance: ${formatEther(transferAmount)} ${currencySymbol} to ${collapseAddress(params.receiver)}`,
      `(Reserving ${formatEther(gasCost)} ${currencySymbol} for gas fees)`,
      false,
      false,
    );

    const txHash = await cm.transferNative({
      to: params.receiver,
      amount: transferAmount,
      gasLimit,
    });

    const receipt = await cm.waitForTransactionReceipt(txHash);

    if (receipt.status !== 'success') {
      throw new Error('Transaction failed');
    }

    printTransactionHash(receipt.transactionHash, config.chainId);
    showText(
      `Successfully transferred ${formatEther(transferAmount)} ${currencySymbol} to ${collapseAddress(params.receiver)}`,
    );
  } catch (error: any) {
    showError({
      text: `Failed to transfer all native currency: ${error.message}`,
    });
  }
};
