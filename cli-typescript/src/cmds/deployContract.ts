import { confirm } from '@inquirer/prompts';
import {
  collapseAddress,
  decodeAddress,
  executeCommand,
  saveDeploymentData,
  supportsICreatorToken,
} from '../utils/common';
import {
  confirmDeployment,
  printSignerWithBalance,
  printTransactionHash,
  showText,
} from '../utils/display';
import {
  freezeContract,
  setTransferList,
  setTransferValidator,
  setupContract,
} from '../utils/contractActions';
import { rpcUrls } from '../utils/constants';
import { ethers } from 'ethers';
import { TransactionData } from '../utils/types';
import {
  setChainID,
  setCollectionName,
  setCollectionSymbol,
  setTokenStandard,
} from '../utils/setters';
import {
  getContractAddressFromLogs,
  getExplorerContractUrl,
  getFactoryAddress,
  getImplId,
  getPasswordOptionIfSet,
  getRegistryAddress,
  getStandardId,
  getUseERC721C,
  getZksyncFlag,
  promptForConfirmation,
} from '../utils/getters';

export const deployContract = async (collectionFile: string) => {
  console.log('Deploying a new collection...');

  // Set chain, token standard, collection name, and symbol
  const chainId = await setChainID();
  const tokenStandard = await setTokenStandard();
  const collectionName = await setCollectionName();
  const collectionSymbol = await setCollectionSymbol();

  // Print signer with balance
  await printSignerWithBalance(chainId);

  const createContractSelector =
    'createContract(string,string,uint8,address,uint32)';
  const factoryAddress = getFactoryAddress(chainId);
  const registryAddress = getRegistryAddress(chainId);
  const standardId = getStandardId(tokenStandard);
  const passwordOption = await getPasswordOptionIfSet();
  const useERC721C = getUseERC721C();
  const implId = getImplId(chainId, tokenStandard, useERC721C);
  const rpcUrl = rpcUrls[chainId];

  showText('Fetching deployment fee...', '', false, false);
  const deploymentFeeCommand = `cast call ${registryAddress} "getDeploymentFee(uint8,uint32)" ${standardId} ${implId} --rpc-url "${rpcUrl}" ${passwordOption}`;
  const deploymentFee = executeCommand(deploymentFeeCommand);

  let value = '0';
  if (deploymentFee !== '0') {
    value = `--value ${ethers.toNumber(deploymentFee)}`;
  }

  await confirmDeployment({
    name: collectionName,
    symbol: collectionSymbol,
    tokenStandard,
    initialOwner: collapseAddress(process.env.SIGNER || ''),
    implId,
    chainId,
    deploymentFee,
  });

  showText('Deploying contract... this may take a minute.', '', false, false);
  const zksyncFlag = getZksyncFlag(chainId);

  const deployCommand = `cast send \
    --rpc-url "${rpcUrl}" \
    "${factoryAddress}" \
    "${createContractSelector}" \
    "${collectionName}" \
    "${collectionSymbol}" \
    "${standardId}" \
    "${process.env.SIGNER}" \
    ${implId} \
    ${zksyncFlag} \
    ${passwordOption} \
    ${value} \
    --json`;

  const output = executeCommand(deployCommand);
  const deploymentData: TransactionData = JSON.parse(output);

  if (!deploymentData.transactionHash) {
    throw new Error(
      'Transaction hash not found in contract deployment output.',
    );
  }

  printTransactionHash(deploymentData.transactionHash, chainId);

  const eventSig = executeCommand(
    `cast sig-event "NewContractInitialized(address,address,uint32,uint8,string,string)"`,
  );
  const eventData = getContractAddressFromLogs(deploymentData, eventSig);
  // extract address from the first 64 characters
  const contractAddress = decodeAddress(eventData?.slice(0, 64) ?? '');

  showText(`Deployed Contract Address: ${contractAddress}`, '', false, false);
  showText(getExplorerContractUrl(chainId, contractAddress), '', false, false);
  saveDeploymentData(contractAddress, process.env.SIGNER || '', collectionFile);

  const isICreatorToken = supportsICreatorToken(
    chainId,
    contractAddress,
    passwordOption,
  );

  if (isICreatorToken) {
    console.log(
      'Contract supports ICreatorToken, updating transfer validator and transfer list...',
    );
    setTransferValidator(contractAddress, chainId);
    await setTransferList(contractAddress, chainId);

    const freezeCollection = await confirm({
      message: 'Would you like to freeze the collection?',
      default: true,
    });

    if (freezeCollection) {
      freezeContract(contractAddress, chainId, passwordOption);
    }
  }

  console.log('');
  const setupNow = await promptForConfirmation(
    'Would you like to setup the contract?',
  );

  if (setupNow) {
    await setupContract({
      contractAddress,
      chainId,
      tokenStandard,
      collectionFile,
      passwordOption,
      signer: process.env.SIGNER!,
      web3StorageKey: process.env.WEB3_STORAGE_KEY,
      baseDir: process.env.BASE_DIR,
      stagesJson: process.env.STAGES_JSON,
    });
  }
};
