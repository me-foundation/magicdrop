import { encodeFunctionData, Hex } from 'viem';
import { TOKEN_STANDARD } from '../constants';
import { actionPresets } from './common';
import { ERC1155M_ABIS, ERC712M_ABIS } from '../../abis';
import { printTransactionHash, showError } from '../display';

export const setMaxMintableSupplyAction = async (
  symbol: string,
  params: {
    tokenId?: number;
    maxMintableSupply: number;
  },
) => {
  try {
    const { cm, config, store } = await actionPresets(symbol);
    if (isNaN(params.maxMintableSupply))
      throw new Error('maxMintableSupply must be a number');

    const maxMintableSupply = Number(params.maxMintableSupply);

    let data: Hex;

    if (config.tokenStandard === TOKEN_STANDARD.ERC721) {
      data = encodeFunctionData({
        abi: [ERC712M_ABIS.setMaxMintableSupply],
        functionName: ERC712M_ABIS.setMaxMintableSupply.name,
        args: [BigInt(maxMintableSupply)],
      });
    } else if (config.tokenStandard === TOKEN_STANDARD.ERC1155) {
      if (params.tokenId === undefined || isNaN(params.tokenId))
        throw Error(
          `The tokenId is required for ${TOKEN_STANDARD.ERC1155} contract.`,
        );

      data = encodeFunctionData({
        abi: [ERC1155M_ABIS.setMaxMintableSupply],
        functionName: ERC1155M_ABIS.setMaxMintableSupply.name,
        args: [BigInt(params.tokenId), BigInt(maxMintableSupply)],
      });
    } else {
      throw new Error('Unsupported token standard. Please check the config.');
    }

    const txHash = await cm.sendTransaction({
      to: config.deployment!.contract_address as Hex,
      data,
    });

    const receipt = await cm.waitForTransactionReceipt(txHash);
    if (receipt.status !== 'success') {
      throw new Error('Transaction failed');
    }

    if (config.tokenStandard === TOKEN_STANDARD.ERC721) {
      store.data!.maxMintableSupply = maxMintableSupply;
    } else if (config.tokenStandard === TOKEN_STANDARD.ERC1155) {
      (store.data!.maxMintableSupply as number[])[params.tokenId!] =
        maxMintableSupply;
    }
    store.write();

    printTransactionHash(receipt.transactionHash, config.chainId);
  } catch (error: any) {
    showError({ text: `Error setting max mintable supply: ${error.message}` });
  }
};
