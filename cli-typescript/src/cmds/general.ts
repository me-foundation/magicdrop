import { Command } from 'commander';
import {
  getCosignerOption,
  getExpiryTimestampOption,
  getForceOption,
  getFreezeThawOption,
  getGlobalWalletLimitOption,
  getIsMintableOption,
  getMaxMintableSupplyOption,
  getMinterActionOption,
  getMinterOption,
  getNewOwnerOption,
  getQtyOption,
  getReceiverOption,
  getStagesFileOption,
  getTokenIdOption,
  getTokenUriSuffixOption,
  getUriOption,
} from '../utils/cmdOptions';
import newWalletAction from '../utils/cmdActions/newWalletAction';
import setUriAction from '../utils/cmdActions/setUriAction';
import initContractAction from '../utils/cmdActions/initContractAction';
import setStagesAction from '../utils/cmdActions/setStagesAction';
import { setGlobalWalletLimitAction } from '../utils/cmdActions/setGlobalWalletLimitAction';
import { setMaxMintableSupplyAction } from '../utils/cmdActions/setMaxMintableSupplyAction';
import { setCosignerAction } from '../utils/cmdActions/setCosignerAction';
import { setTimestampExpiryAction } from '../utils/cmdActions/setTimestampExpiryAction';
import { withdrawContractBalanceAction } from '../utils/cmdActions/withdrawContractBalanceAction';
import { TOKEN_STANDARD } from '../utils/constants';
import { freezeThawContractAction } from '../utils/cmdActions/freezeThawContractAction';
import { transferOwnershipAction } from '../utils/cmdActions/transferOwnershipAction';
import { manageAuthorizedMintersAction } from '../utils/cmdActions/manageAuthorizedMinters';
import { setMintableAction } from '../utils/cmdActions/setMintableAction';
import { setTokenUriSuffixAction } from '../utils/cmdActions/setTokenUriSuffixAction';
import { ownerMintAction } from '../utils/cmdActions/ownerMintAction';
import { checkSignerBalanceAction } from '../utils/cmdActions/checkSignerBalanceAction';
import getWalletInfoAction from '../utils/cmdActions/getWalletInfoAction';
import getProjectConfigAction from '../utils/cmdActions/getProjectConfigAction';

export const createNewWalletCmd = () =>
  new Command('create-wallet')
    .command('create-wallet <symbol>')
    .description('create a new wallet for a collection')
    .action(newWalletAction);

export const initContractCmd = () =>
  new Command('init-contract')
    .command('init-contract <symbol>')
    .description('Initializes/Set up a deployed collection (contract).')
    .addOption(getStagesFileOption().makeOptionMandatory(false))
    .action(initContractAction);

export const setUriCmd = () =>
  new Command('set-uri')
    .command('set-uri <symbol>')
    .addOption(getUriOption().makeOptionMandatory())
    .description(
      'Set the URI for the collection. Note: this will overwrite the existing URI.',
    )
    .action(setUriAction);

export const setStagesCmd = () =>
  new Command('set-stages')
    .command('set-stages <symbol>')
    .addOption(getStagesFileOption())
    .description(
      `Set the stages for the collection. Note: this will overwrite the existing stages. You can provide a stages file or update the existing stages in the config.`,
    )
    .action(setStagesAction);

export const setGlobalWalletLimitCmd = () =>
  new Command('set-global-wallet-limit')
    .command('set-global-wallet-limit <symbol>')
    .alias('sgwl')
    .description(
      'Set the globalWalletLimit for the collection. Note: this will overwrite the existing global wallet limit.',
    )
    .addOption(getGlobalWalletLimitOption().makeOptionMandatory())
    .addOption(getTokenIdOption())
    .action(setGlobalWalletLimitAction);

export const setMaxMintableSupplyCmd = () =>
  new Command('set-max-mintable-supply')
    .command('set-max-mintable-supply <symbol>')
    .alias('smms')
    .description(
      'Set the maxMintableSupply for the collection. Note: this will overwrite the existing maxMintableSupply.',
    )
    .addOption(getMaxMintableSupplyOption().makeOptionMandatory())
    .addOption(getTokenIdOption())
    .action(setMaxMintableSupplyAction);

export const setCosginerCmd = () =>
  new Command('set-cosigner')
    .command('set-cosigner <symbol>')
    .addOption(getCosignerOption().makeOptionMandatory())
    .description(
      `Set the cosigner for the collection. Note: this will overwrite the existing cosigner. Support for ${TOKEN_STANDARD.ERC721} only.`,
    )
    .action(setCosignerAction);

export const setTimestampExpiryCmd = () =>
  new Command('set-expiry')
    .command('set-timestamp-expiry <symbol>')
    .alias('set-expiry')
    .addOption(getExpiryTimestampOption().makeOptionMandatory())
    .description(
      `Sets expiry in seconds. This timestamp specifies how long a signature from cosigner is valid for. Support for ${TOKEN_STANDARD.ERC721} only.`,
    )
    .action(setTimestampExpiryAction);

export const withdrawContractBalanceCmd = () =>
  new Command('withdraw-contract-balance')
    .command('withdraw-contract-balance <symbol>')
    .description('Withdraws the contract balance to the specified address.')
    .action(withdrawContractBalanceAction);

export const freezeThawContractCmd = () =>
  new Command('freeze-thaw-contract')
    .command('freeze-thaw-contract <symbol>')
    .alias('ftc')
    .alias('freeze-thaw')
    .description('Freeze or Thaw contract.')
    .addOption(getFreezeThawOption().makeOptionMandatory())
    .action(freezeThawContractAction);

export const transferOwnershipCmd = () =>
  new Command('transfer-ownership')
    .command('transfer-ownership <symbol>')
    .description(
      'Allows the owner to transfer the collection ownership to `newOwner`.',
    )
    .addOption(getNewOwnerOption().makeOptionMandatory())
    .action(transferOwnershipAction);

export const manageAuthorizedMintersCmd = () =>
  new Command('manage-authorized-minters')
    .command('manage-authorized-minters <symbol>')
    .alias('mam')
    .alias('manage-minters')
    .description('Add/Remove authorized minters to the collection.')
    .addOption(getMinterOption().makeOptionMandatory())
    .addOption(getMinterActionOption().makeOptionMandatory())
    .action(manageAuthorizedMintersAction);

export const setMintableCmd = () =>
  new Command('set-mintable')
    .command('set-mintable <symbol>')
    .description(
      `Sets mintable for the collection. this will overwrite the existing mintable value. Support for ${TOKEN_STANDARD.ERC721} only.`,
    )
    .addOption(getIsMintableOption())
    .action(setMintableAction);

export const setTokenURISuffixCmd = () =>
  new Command('set-token-uri-suffix')
    .command('set-token-uri-suffix <symbol>')
    .alias('stus')
    .description(
      `Sets the tokenURISuffix for the collection. This will overwrite the existing tokenUriSuffix value. Support for ${TOKEN_STANDARD.ERC721} only.`,
    )
    .addOption(getTokenUriSuffixOption().makeOptionMandatory())
    .action(setTokenUriSuffixAction);

export const ownerMintCmd = () =>
  new Command('owner-mint')
    .command('owner-mint <symbol>')
    .description(
      'Mints token(s) by owner. NOTE: This function bypasses validations thus only available for owner. This is typically used for owner to pre-mint or mint the remaining of the supply.',
    )
    .addOption(getReceiverOption().makeOptionMandatory())
    .addOption(getTokenIdOption())
    .addOption(getQtyOption().makeOptionMandatory())
    .action(ownerMintAction);

export const getWalletInfoCmd = () =>
  new Command('get-wallet-info')
    .command('get-wallet-info <symbol>')
    .alias('gwi')
    .description('Get the wallet info for a collection')
    .action(getWalletInfoAction);

export const getConfigCmd = () =>
  new Command('get-config')
    .command('get-config <symbol>')
    .alias('gc')
    .description(
      'Retrieve the project configuration for a specific collection.',
    )
    .action(getProjectConfigAction);

export const checkSignerBalanceCmd = () =>
  new Command('check-signer-balance')
    .command('check-signer-balance <symbol>')
    .alias('csb')
    .description('Check the balance of the signer account for the collection.')
    .action(checkSignerBalanceAction);
