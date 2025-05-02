import { Hex } from 'viem';
import { actionPresets } from './common';
import { printTransactionHash, showError, showText } from '../display';
import { TOKEN_STANDARD } from '../constants';

export const freezeThawContractAction = async (
  symbol: string,
  params: {
    choice: 'freeze' | 'thaw';
  },
) => {
  try {
    const { cm, config } = await actionPresets(symbol);

    if (config.tokenStandard !== TOKEN_STANDARD.ERC1155)
      throw new Error(
        `this action is only supported for ${TOKEN_STANDARD.ERC1155} collections`,
      );

    showText(
      `You're about to ${params.choice} the contract: ${config.deployment!.contract_address}`,
      '',
      false,
      false,
    );

    const txHash = await cm.freezeThawContract(
      config.deployment!.contract_address as Hex,
      params.choice === 'freeze',
    );

    const receipt = await cm.waitForTransactionReceipt(txHash);

    if (receipt.status !== 'success') {
      throw new Error('Transaction failed');
    }

    printTransactionHash(receipt.transactionHash, config.chainId);

    console.log(
      `Token transfers ${params.choice === 'freeze' ? 'frozen' : 'thawed'}.`,
    );
  } catch (error: any) {
    showError({ text: `Failed to ${params.choice}: ${error.message}` });
  }
};
