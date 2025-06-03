import { Command } from 'commander';
import {
  getConfigFileOption,
  getEnvOption,
  getSetupContractOption,
  getSetupWalletOption,
  getStagesFileOption,
  getTokenStandardOption,
  getTotalTokensOption,
} from '../utils/cmdOptions';
import { EvmPlatform } from '../utils/evmUtils';
import deployAction from '../utils/cmdActions/deployAction';
import { setBaseDir } from '../utils/setters';
import { showError } from '../utils/display';
import { supportedChainNames, TOKEN_STANDARD } from '../utils/constants';
import newProjectAction from '../utils/cmdActions/newProjectAction';
import {
  checkSignerBalanceCmd,
  createNewWalletCmd,
  freezeThawContractCmd,
  getConfigCmd,
  getWalletInfoCmd,
  initContractCmd,
  manageAuthorizedMintersCmd,
  ownerMintCmd,
  setCosginerCmd,
  setGlobalWalletLimitCmd,
  setMaxMintableSupplyCmd,
  setMintableCmd,
  setMintFeeCmd,
  setStagesCmd,
  setTimestampExpiryCmd,
  setTokenURISuffixCmd,
  setUriCmd,
  transferOwnershipCmd,
  withdrawContractBalanceCmd,
} from './general';
import listProjectsAction from '../utils/cmdActions/listProjectsAction';
import { getProjectStore } from '../utils/fileUtils';
import fillProjectConfigAction from '../utils/cmdActions/fillProjectConfigAction';
import { authenticate } from '../utils/auth';
import { getCollectionDir } from '../utils/getters';

export const getNewProjectCmdDescription = (defaultInfo?: string) => {
  defaultInfo =
    defaultInfo ||
    'The default chain is monad testnet and the default token standard is ERC721.';
  return `
    Creates a new launchpad/collection template. 
    you can specify the collection directory by setting the "MAGIC_DROP_COLLECTION_DIR" env 
    else it defaults to "${getCollectionDir()}" in the project directory.
    You can also specify the chain and token standard to use for the new project.
    ${defaultInfo}
  `;
};

const presets = async (cliCmd: string) => {
  try {
    console.log('Starting prestart tasks...');

    console.log('Authenticating...');
    await authenticate();

    // set cmd name globally
    process.env.MAGICDROP_CLI_CMD = cliCmd;

    setBaseDir();
  } catch (error: any) {
    showError({ text: `An error occurred: ${error.message}` });
    process.exit(1);
  }
};

const SUBCOMMAND_EXCLUDE_LIST = ['new', 'list'];

export const createEvmCommand = ({
  platform,
  commandAliases,
}: {
  platform: EvmPlatform;
  commandAliases: string[];
}) => {
  const newCmd = new Command(platform.name.toLowerCase())
    .name(platform.name.toLowerCase())
    .description(`${platform.name} launchpad commands`)
    .aliases(commandAliases);

  newCmd.hook('preAction', async (_, actionCommand) => {
    try {
      await presets(actionCommand.name());
    } catch (error: any) {
      showError({ text: `setup failed - ${error.message}` });
    }
  });

  // subcommand hook; verify if the collection is supported on the platform
  newCmd.hook('preAction', (_, actionCommand) => {
    const symbol = actionCommand.args[0];

    if (!SUBCOMMAND_EXCLUDE_LIST.includes(actionCommand.name()) && !!symbol) {
      const store = getProjectStore(symbol);
      store.read();

      if (!platform.isChainIdSupported(store.data?.chainId ?? 0)) {
        showError({
          text: `collection '${symbol}' not supported on the ${platform.name} platform.`,
        });

        process.exit(1);
      }
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
    .command('list')
    .alias('ls')
    .description(
      `list all collections/projects supported on the ${platform.name} platform`,
    )
    .action(async () => await listProjectsAction(platform));

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

  newCmd
    .command('configure-project <symbol>')
    .description(
      'Configure the project for a specific collection. Note: this will work only for not-yet-deployed projects.',
    )
    .addOption(getConfigFileOption().makeOptionMandatory())
    .action(
      async (
        symbol: string,
        params: {
          configFile: string;
        },
      ) => {
        await fillProjectConfigAction(platform, symbol, params);
      },
    );

  newCmd.addCommand(createNewWalletCmd());
  newCmd.addCommand(initContractCmd());
  newCmd.addCommand(setUriCmd());
  newCmd.addCommand(setStagesCmd());
  newCmd.addCommand(setMintFeeCmd());
  newCmd.addCommand(setGlobalWalletLimitCmd());
  newCmd.addCommand(setMaxMintableSupplyCmd());
  newCmd.addCommand(setCosginerCmd());
  newCmd.addCommand(setTimestampExpiryCmd());
  newCmd.addCommand(withdrawContractBalanceCmd());
  newCmd.addCommand(freezeThawContractCmd());
  newCmd.addCommand(transferOwnershipCmd());
  newCmd.addCommand(manageAuthorizedMintersCmd());
  newCmd.addCommand(setMintableCmd());
  newCmd.addCommand(setTokenURISuffixCmd());
  newCmd.addCommand(ownerMintCmd());
  newCmd.addCommand(checkSignerBalanceCmd());
  newCmd.addCommand(getWalletInfoCmd());
  newCmd.addCommand(getConfigCmd());

  return newCmd;
};
