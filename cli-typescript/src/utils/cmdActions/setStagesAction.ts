import { encodeFunctionData, Hex } from 'viem';
import { ContractManager } from '../ContractManager';
import { ERC1155M_ABIS, ERC712M_ABIS } from '../../abis';
import { printTransactionHash, showError, showText } from '../display';
import {
  getERC1155ParsedStagesData,
  getERC721ParsedStagesData,
  processStages,
} from '../deployContract';
import { TOKEN_STANDARD } from '../constants';
import { ERC1155StageData, ERC721StageData } from '../types';
import { actionPresets } from './common';

export const setStagesAction = async (
  symbol: string,
  params: {
    stagesFile?: string;
  },
) => {
  try {
    const { cm, config, store } = await actionPresets(symbol);

    // Process stages data
    console.log('Processing stages data... this will take a moment.');
    const stagesData = await processStages({
      collectionFile: store.root,
      stagesFile: params.stagesFile,
      stagesJson: JSON.stringify(config.stages),
      tokenStandard: config.tokenStandard,
    });

    showText(`Setting stages for ${config.tokenStandard} collection...`);

    let txHash: Hex;

    if (config.tokenStandard === TOKEN_STANDARD.ERC721) {
      txHash = await sendERC721StagesTransaction(
        cm,
        config.deployment?.contract_address as Hex,
        getERC721ParsedStagesData(stagesData as ERC721StageData[]),
      );
    } else if (config.tokenStandard === TOKEN_STANDARD.ERC1155) {
      txHash = await sendERC1155SetupTransaction(
        cm,
        config.deployment?.contract_address as Hex,
        getERC1155ParsedStagesData(stagesData as ERC1155StageData[]),
      );
    } else {
      throw new Error('Unsupported token standard. Please check the config.');
    }

    printTransactionHash(txHash, config.chainId);
  } catch (error: any) {
    showError({ text: `Error setting stages: ${error.message}` });
  }
};

const sendERC721StagesTransaction = async (
  cm: ContractManager,
  contractAddress: Hex,
  stagesData: ReturnType<typeof getERC721ParsedStagesData>,
) => {
  const args = stagesData.map((stage) => {
    return {
      price: stage[0],
      mintFee: stage[1],
      walletLimit: stage[2],
      merkleRoot: stage[3],
      maxStageSupply: stage[4],
      startTimeUnixSeconds: stage[5],
      endTimeUnixSeconds: stage[6],
    } as {
      price: bigint;
      mintFee: bigint;
      walletLimit: number;
      merkleRoot: Hex;
      maxStageSupply: number;
      startTimeUnixSeconds: bigint;
      endTimeUnixSeconds: bigint;
    };
  });
  const data = encodeFunctionData({
    abi: [ERC712M_ABIS.setStages],
    functionName: ERC712M_ABIS.setStages.name,
    args: [args],
  });

  const txHash = await cm.sendTransaction({
    to: contractAddress,
    data,
  });

  const receipt = await cm.waitForTransactionReceipt(txHash);
  if (receipt.status !== 'success') {
    throw new Error('Transaction failed');
  }

  return receipt.transactionHash;
};

const sendERC1155SetupTransaction = async (
  cm: ContractManager,
  contractAddress: Hex,
  stagesData: ReturnType<typeof getERC1155ParsedStagesData>,
) => {
  const args = stagesData.map((stage) => {
    return {
      price: stage[0],
      mintFee: stage[1],
      walletLimit: stage[2],
      merkleRoot: stage[3],
      maxStageSupply: stage[4],
      startTimeUnixSeconds: stage[5],
      endTimeUnixSeconds: stage[6],
    } as {
      price: bigint[];
      mintFee: bigint[];
      walletLimit: number[];
      merkleRoot: `0x${string}`[];
      maxStageSupply: number[];
      startTimeUnixSeconds: bigint;
      endTimeUnixSeconds: bigint;
    };
  });

  const data = encodeFunctionData({
    abi: [ERC1155M_ABIS.setStages],
    functionName: ERC1155M_ABIS.setStages.name,
    args: [args],
  });

  const txHash = await cm.sendTransaction({
    to: contractAddress,
    data,
  });

  const receipt = await cm.waitForTransactionReceipt(txHash);
  if (receipt.status !== 'success') {
    throw new Error('Transaction failed');
  }

  return receipt.transactionHash;
};

export default setStagesAction;
