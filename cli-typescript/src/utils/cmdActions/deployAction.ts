import { deployContract } from '../deployContract';
import { showError } from '../display';
import { EvmPlatform, init, validateConfig } from '../evmUtils';

const deployAction = async (
  platform: EvmPlatform,
  collection: string,
  params: {
    env: string;
    setupContract: 'yes' | 'no' | 'deferred';
  },
) => {
  try {
    const { env, ...cliOptions } = params;
    const signer = process.env.SIGNER!;

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
    );

    if (!isValid) {
      throw new Error(
        'Invalid configuration. Please check your config file and CLI options.',
      );
    }

    await deployContract({
      ...mergedConfig,
      signer,
      collectionConfigFile,
      setupContractOption: cliOptions.setupContract,
    });

    console.log('Contract deployed successfully!');
  } catch (error: any) {
    showError({ text: `Error deploying contract: ${error.message}` });
    process.exit(1);
  }
};

export default deployAction;
