import { confirm } from '@inquirer/prompts';
import {
  collapseAddress,
  decodeAddress,
  executeCommand,
  saveDeploymentData,
  supportsICreatorToken,
} from './common';
import {
  confirmDeployment,
  printSignerWithBalance,
  printTransactionHash,
  showText,
} from './display';
import {
  freezeContract,
  setTransferList,
  setTransferValidator,
  setupContract,
} from './contractActions';
import { rpcUrls } from './constants';
import { ethers } from 'ethers';
import { DeployContractConfig, TransactionData } from './types';
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
} from './getters';

export const deployContract = async ({
  chainId,
  collectionConfigFile,
  tokenStandard,
  signer,
  stages,
  name: collectionName,
  symbol: collectionSymbol,
  maxMintableSupply,
  royaltyFee,
  royaltyReceiver,
  globalWalletLimit,
  fundReceiver,
  setupContractOption,
  uri,
  tokenUriSuffix,
  mintCurrency,
}: DeployContractConfig) => {
  showText('Deploying a new collection...');

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
    initialOwner: collapseAddress(signer || ''),
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
    "${signer}" \
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
    'cast sig-event "NewContractInitialized(address,address,uint32,uint8,string,string)"',
  );
  const eventData = getContractAddressFromLogs(deploymentData, eventSig);
  // extract address from the first 64 characters
  const contractAddress = decodeAddress(eventData?.slice(0, 64) ?? '');

  showText(`Deployed Contract Address: ${contractAddress}`, '', false, false);
  showText(getExplorerContractUrl(chainId, contractAddress), '', false, false);
  saveDeploymentData(contractAddress, signer, collectionConfigFile);

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

  const setupNow =
    setupContractOption === 'yes' ||
    (setupContractOption === 'deferred' &&
      (await promptForConfirmation('Would you like to setup the contract?')));

  if (setupNow) {
    await setupContract({
      contractAddress,
      chainId,
      tokenStandard,
      collectionFile: collectionConfigFile,
      signer,
      baseDir: process.env.BASE_DIR,
      uri,
      tokenUriSuffix,
      passwordOption,
      stagesJson: JSON.stringify(stages),
      totalTokens: undefined,
      globalWalletLimit,
      maxMintableSupply,
      fundReceiver,
      royaltyReceiver,
      royaltyFee,
      mintCurrency,
    });
  }
};
