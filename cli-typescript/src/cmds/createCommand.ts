import { Command } from 'commander';
import {
  getEnvOption,
  getSetupContractOption,
  getSetupWalletOption,
  getStagesFileOption,
  getTokenStandardOption,
  getTotalTokensOption,
} from '../utils/cmdOptions';
import { EvmPlatform } from '../utils/evmUtils';
import deployAction from '../utils/cmdActions/deployAction';
import { loadDefaults } from '../utils/loaders';
import { setBaseDir } from '../utils/setters';
import { showError } from '../utils/display';
import {
  COLLECTION_DIR,
  supportedChainNames,
  TOKEN_STANDARD,
} from '../utils/constants';
import newProjectAction from '../utils/cmdActions/newProjectAction';
import {
  createNewWalletCmd,
  freezeThawContractCmd,
  initContractCmd,
  listProjectsCmd,
  manageAuthorizedMintersCmd,
  ownerMintCmd,
  setCosginerCmd,
  setGlobalWalletLimitCmd,
  setMaxMintableSupplyCmd,
  setMintableCmd,
  setStagesCmd,
  setTimestampExpiryCmd,
  setTokenURISuffixCmd,
  setUriCmd,
  transferOwnershipCmd,
  withdrawContractBalanceCmd,
} from './general';

export const getNewProjectCmdDescription = (defaultInfo?: string) => {
  defaultInfo =
    defaultInfo ||
    'The default chain is monad testnet and the default token standard is ERC721.';
  return `
    Creates a new launchpad/collection template. 
    you can specify the collection directory by setting the "MAGIC_DROP_COLLECTION_DIR" env 
    else it defaults to "${COLLECTION_DIR}" in the project directory.
    You can also specify the chain and token standard to use for the new project.
    ${defaultInfo}
  `;
};

const presets = async () => {
  try {
    console.log('Starting prestart tasks...');

    setBaseDir();

    // Load default configurations
    await loadDefaults();

    // Check if the default configuration is complete
    if (process.env.DEFAULT_CONFIG_COMPLETE !== 'true') {
      throw new Error(
        'Configuration is incomplete. Please ensure all values are set in defaults.json.',
      );
    }
  } catch (error: any) {
    showError({ text: `An error occurred: ${error.message}` });
    process.exit(1);
  }
};

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

  newCmd.hook('preAction', async () => {
    try {
      await presets();
    } catch (error: any) {
      showError({ text: `setup failed - ${error.message}` });
    }
  });

  newCmd
    .command('new <symbol>')
    .aliases(['n', 'init'])
    .description(
      getNewProjectCmdDescription(
        `The default environment is ${platform.defaultChain} and the default token standard is ERC721.`,
      ),
    )
    .addOption(
      getEnvOption(
        Array.from(platform.chainIdsMap.keys()),
        'Environment to deploy to',
        platform.defaultChain,
      ),
    )
    .addOption(getTokenStandardOption())
    .addOption(getSetupWalletOption())
    .action(
      async (
        symbol: string,
        params: {
          env: string;
          tokenStandard: TOKEN_STANDARD;
          setupWallet: boolean;
        },
      ) =>
        await newProjectAction(symbol, {
          chain:
            supportedChainNames[
              platform.chainIdsMap.get(params.env) ??
                platform.chainIdsMap.get(platform.defaultChain)!
            ],
          tokenStandard: params.tokenStandard,
          setupWallet: params.setupWallet,
        }),
    );

  newCmd
    .command('deploy <symbol>')
    .description(
      'Deploys an ERC721 or ERC1155 collection with the given parameters',
    )
    .addOption(
      getEnvOption(
        Array.from(platform.chainIdsMap.keys()),
        'Environment to deploy to',
        platform.defaultChain,
      ),
    )
    .addOption(getSetupContractOption())
    .addOption(getTotalTokensOption())
    .addOption(getStagesFileOption().makeOptionMandatory(false))
    .action(
      async (
        symbol: string,
        params: {
          env: string;
          setupContract: 'yes' | 'no' | 'deferred';
          totalTokens?: number;
          stagesFile?: string;
        },
      ) => await deployAction(platform, symbol, params),
    );

  newCmd.addCommand(createNewWalletCmd);
  newCmd.addCommand(listProjectsCmd);
  newCmd.addCommand(initContractCmd);
  newCmd.addCommand(setUriCmd);
  newCmd.addCommand(setStagesCmd);
  newCmd.addCommand(setGlobalWalletLimitCmd);
  newCmd.addCommand(setMaxMintableSupplyCmd);
  newCmd.addCommand(setCosginerCmd);
  newCmd.addCommand(setTimestampExpiryCmd);
  newCmd.addCommand(withdrawContractBalanceCmd);
  newCmd.addCommand(freezeThawContractCmd);
  newCmd.addCommand(transferOwnershipCmd);
  newCmd.addCommand(manageAuthorizedMintersCmd);
  newCmd.addCommand(setMintableCmd);
  newCmd.addCommand(setTokenURISuffixCmd);
  newCmd.addCommand(ownerMintCmd);

  return newCmd;
};
