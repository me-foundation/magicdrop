import { ContractManager } from '../ContractManager';
import { deployContract } from '../deployContract';
import { showError } from '../display';
import { EvmPlatform, init, validateConfig } from '../evmUtils';
import { getProjectSigner } from '../turnkey';

const deployAction = async (
  platform: EvmPlatform,
  collection: string,
  params: {
    env: string;
    setupContract: 'yes' | 'no' | 'deferred';
    totalTokens: number;
  },
) => {
  try {
    const { env, ...cliOptions } = params;

    const { config, collectionConfigFile } = init(collection);

    // Step 2: Override config file with CLI flag options if provided
    const mergedConfig = {
      ...config,
      ...cliOptions,
    };

    // validate config
    const isValid = validateConfig(
      platform,
      mergedConfig,
      cliOptions.setupContract === 'yes',
      cliOptions.totalTokens,
    );

    if (!isValid) {
      throw new Error(
        'Invalid configuration. Please check your config file and CLI options.',
      );
    }

    const { signer } = await getProjectSigner(collection);

    const cm = new ContractManager(mergedConfig.chainId, signer);

    await deployContract({
      ...mergedConfig,
      collectionConfigFile,
      setupContractOption: cliOptions.setupContract,
      contractManager: cm,
    });

    console.log('Contract deployed successfully!');
  } catch (error: any) {
    showError({ text: `Error deploying contract: ${error.message}` });
    process.exit(1);
  }
};

export default deployAction;
