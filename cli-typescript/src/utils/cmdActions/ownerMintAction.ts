import { encodeFunctionData, Hex, isAddress } from 'viem';
import { actionPresets } from './common';
import { ERC1155M_ABIS, ERC712M_ABIS } from '../../abis';
import { printTransactionHash, showError } from '../display';
import { collapseAddress } from '../common';
import { TOKEN_STANDARD } from '../constants';

export const ownerMintAction = async (
  collection: string,
  { receiver, tokenId, qty }: { receiver: Hex; tokenId?: number; qty: number },
) => {
  try {
    const { cm, config } = await actionPresets(collection);
    const errors = [];
    if (!isAddress(receiver)) {
      errors.push('receiver must be a valid address');
    }

    if (isNaN(qty) || qty <= 0) {
      errors.push('qty must be greater than 0');
    }

    if (
      config.tokenStandard === TOKEN_STANDARD.ERC1155 &&
      (!tokenId || isNaN(tokenId) || tokenId < 0)
    ) {
      errors.push('tokenId must be greater than or equal to 0');
    }

    if (errors.length > 0) {
      throw new Error(errors.join(', '));
    }

    let data: Hex;
    if (config.tokenStandard === TOKEN_STANDARD.ERC721) {
      console.log(
        `You are about to mint ${qty} token(s) to ${collapseAddress(receiver)}.`,
      );

      data = encodeFunctionData({
        abi: [ERC712M_ABIS.ownerMint],
        functionName: ERC712M_ABIS.ownerMint.name,
        args: [qty, receiver],
      });
    } else if (config.tokenStandard === TOKEN_STANDARD.ERC1155) {
      console.log(
        `You are about to mint ${qty} token(s) to ${collapseAddress(receiver)} for token ${tokenId}.`,
      );

      data = encodeFunctionData({
        abi: [ERC1155M_ABIS.ownerMint],
        functionName: ERC1155M_ABIS.ownerMint.name,
        args: [receiver, BigInt(tokenId!), qty],
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

    printTransactionHash(receipt.transactionHash, config.chainId);
  } catch (error: any) {
    showError({ text: `Failed to mint: ${error.message}` });
  }
};
