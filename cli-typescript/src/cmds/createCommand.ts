import { Command } from 'commander';
import { deployContract } from './deployContract';
import {
  collectionConfigFile,
  getEnvOption,
  setupContractOption,
} from './cmdOptions';
import { EvmPlatform, validateConfig } from '../utils/evmUtils';
import { Collection } from '../utils/types';
import { loadCollection } from '../utils/loaders';
import { supportedChainNames } from '../utils/constants';
import { showError } from '../utils/display';

export const createEvmCommand = ({
  platform,
  commandAliases,
}: {
  platform: EvmPlatform;
  commandAliases: string[];
}) => {
  const newCmd = new Command()
    .name(platform.name.toLowerCase())
    .description(`${platform.name} launchpad commands`)
    .aliases(commandAliases);

  newCmd
    .command('deploy')
    .description(
      'Deploys an ERC721 or ERC1155 contract with the given parameters',
    )
    .addOption(collectionConfigFile.makeOptionMandatory())
    .addOption(
      getEnvOption(
        `Environment to deploy to (e.g., ${Array.from(platform.chainIdsMap.keys())}`,
        supportedChainNames[platform.defaultChain],
      ),
    )
    .addOption(setupContractOption)
    .action(
      async (params: {
        env: string;
        collectionConfigFile: string;
        setupContract: 'yes' | 'no' | 'deferred';
      }) => {
        try {
          const { env, collectionConfigFile, ...cliOptions } = params;
          const signer = process.env.SIGNER!;

          // Step 1: Load config file via collectionConfigFile
          const config: Collection = loadCollection(collectionConfigFile);

          // Step 2: Override config file with CLI flag options if provided
          const mergedConfig = {
            ...config,
            ...cliOptions,
          };

          console.log('Merged Config: ', mergedConfig);

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
      },
    );

  return newCmd;
};
