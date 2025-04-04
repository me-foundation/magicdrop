import { confirm } from '@inquirer/prompts';
import {
  decodeAddress,
  executeCommand,
  getContractAddressFromLogs,
  getExplorerContractUrl,
  getFactoryAddress,
  getImplId,
  getPasswordIfSet,
  getRegistryAddress,
  getStandardId,
  getUseERC721C,
  getZksyncFlag,
  promptForConfirmation,
  saveDeploymentData,
  setChainID,
  setCollectionName,
  setCollectionSymbol,
  setTokenStandard,
  supportsICreatorToken,
} from '../utils/common';
import {
  confirmDeployment,
  printSignerWithBalance,
  printTransactionHash,
} from '../utils/display';
import {
  freezeContract,
  setTransferList,
  setTransferValidator,
  setupContract,
} from '../utils/contractActions';

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
  const password = await getPasswordIfSet();
  const useERC721C = getUseERC721C();
  const implId = getImplId(chainId, tokenStandard, useERC721C);

  console.log('Fetching deployment fee...');
  const deploymentFeeCommand = `cast call ${registryAddress} "getDeploymentFee(uint8,uint32)" ${standardId} ${implId} --rpc-url "$RPC_URL" ${password}`;
  const deploymentFee = executeCommand(deploymentFeeCommand);

  let value = '';
  if (deploymentFee !== '0') {
    value = `--value ${deploymentFee}`;
  }

  await confirmDeployment({
    name: collectionName,
    symbol: collectionSymbol,
    tokenStandard,
    initialOwner: process.env.SIGNER || '',
    implId,
    chainId,
    deploymentFee,
  });
  // eheee

  console.log('Deploying contract... this may take a minute.');
  const zksyncFlag = getZksyncFlag(chainId);

  const deployCommand = `cast send \
    --rpc-url "$RPC_URL" \
    ${factoryAddress} \
    "${createContractSelector}" \
    "${collectionName}" \
    "${collectionSymbol}" \
    "${standardId}" \
    "${process.env.SIGNER}" \
    ${implId} \
    ${zksyncFlag} \
    ${password} \
    ${value} \
    --json`;

  const output = executeCommand(deployCommand);

  printTransactionHash(output, chainId);

  const sigEvent = `cast sig-event "NewContractInitialized(address,address,uint32,uint8,string,string)"`;
  const eventData = getContractAddressFromLogs(output, sigEvent);
  const contractAddress = decodeAddress(eventData);

  console.log(`Deployed Contract Address: ${contractAddress}`);
  console.log(getExplorerContractUrl(chainId, contractAddress));
  saveDeploymentData(contractAddress, process.env.SIGNER || '', collectionFile);

  const isICreatorToken = supportsICreatorToken(
    chainId,
    contractAddress,
    password,
  );

  if (isICreatorToken) {
    console.log(
      'Contract supports ICreatorToken, updating transfer validator and transfer list...',
    );
    setTransferValidator(contractAddress, chainId);
    await setTransferList(contractAddress, chainId);
  }

  if (isICreatorToken) {
    const freezeCollection = await confirm({
      message: 'Would you like to freeze the collection?',
      default: true,
    });

    if (freezeCollection) {
      await freezeContract(contractAddress, chainId, password);
    }
  }

  const setupNow = await promptForConfirmation(
    'Would you like to setup the contract?',
  );

  if (setupNow) {
    await setupContract({
      contractAddress,
      chainId,
      tokenStandard,
      collectionFile,
      password,
      signer: process.env.SIGNER!,
      web3StorageKey: process.env.WEB3_STORAGE_KEY,
      baseDir: process.env.BASE_DIR,
      stagesJson: process.env.STAGES_JSON,
    });
  }
};
