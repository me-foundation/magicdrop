import { Command } from 'commander';
import newProjectAction from '../utils/cmdActions/newProjectAction';
import {
  getChainOption,
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
  getSetupWalletOption,
  getStagesFileOption,
  getTokenIdOption,
  getTokenStandardOption,
  getTokenUriSuffixOption,
  getUriOption,
} from '../utils/cmdOptions';
import listProjectsAction from '../utils/cmdActions/listProjectsAction';
import { getNewProjectCmdDescription } from '../utils/createCommand';
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

export const newProjectCmd = new Command('new')
  .command('new <collection>')
  .aliases(['n', 'init'])
  .description(getNewProjectCmdDescription())
  .addOption(getChainOption())
  .addOption(getTokenStandardOption())
  .addOption(getSetupWalletOption())
  .action(newProjectAction);

export const createNewWalletCmd = new Command('create-wallet')
  .command('create-wallet <collection>')
  .description('create a new wallet for a collection')
  .addOption(
    getForceOption(
      `
    overwrite the existing wallet.json for the collection.
    Note: this will NOT delete the existing wallet in turnkey if a wallet with the same collection name already exists.
    Please reconcile manually in turnkey if you want to delete the existing wallet.
  `,
      false,
    ),
  )
  .action(newWalletAction);

export const listProjectsCmd = new Command('list')
  .alias('ls')
  .description('list all local collections/projects')
  .action(listProjectsAction);

export const initContractCmd = new Command('init-contract')
  .command('init-contract <collection>')
  .description('Initializes/Set up a deployed collection (contract).')
  .addOption(getStagesFileOption().makeOptionMandatory(false))
  .action(initContractAction);

export const setUriCmd = new Command('set-uri')
  .command('set-uri <collection>')
  .addOption(getUriOption().makeOptionMandatory())
  .description(
    'Set the URI for the collection. Note: this will overwrite the existing URI.',
  )
  .action(setUriAction);

export const setStagesCmd = new Command('set-stages')
  .command('set-stages <collection>')
  .addOption(getStagesFileOption().makeOptionMandatory())
  .description(
    'Set the stages for the collection. Note: this will overwrite the existing stages.',
  )
  .action(setStagesAction);

export const setGlobalWalletLimitCmd = new Command('set-global-wallet-limit')
  .command('set-global-wallet-limit <collection>')
  .alias('sgwl')
  .description(
    'Set the globalWalletLimit for the collection. Note: this will overwrite the existing global wallet limit.',
  )
  .addOption(getGlobalWalletLimitOption().makeOptionMandatory())
  .addOption(getTokenIdOption())
  .action(setGlobalWalletLimitAction);

export const setMaxMintableSupplyCmd = new Command('set-max-mintable-supply')
  .command('set-max-mintable-supply <collection>')
  .alias('smms')
  .description(
    'Set the maxMintableSupply for the collection. Note: this will overwrite the existing maxMintableSupply.',
  )
  .addOption(getMaxMintableSupplyOption().makeOptionMandatory())
  .addOption(getTokenIdOption())
  .action(setMaxMintableSupplyAction);

export const setCosginerCmd = new Command('set-cosigner')
  .command('set-cosigner <collection>')
  .addOption(getCosignerOption().makeOptionMandatory())
  .description(
    `Set the cosigner for the collection. Note: this will overwrite the existing cosigner. Support for ${TOKEN_STANDARD.ERC721} only.`,
  )
  .action(setCosignerAction);

export const setTimestampExpiryCmd = new Command('set-expiry')
  .command('set-timestamp-expiry <collection>')
  .alias('set-expiry')
  .addOption(getExpiryTimestampOption().makeOptionMandatory())
  .description(
    `Sets expiry in seconds. This timestamp specifies how long a signature from cosigner is valid for. Support for ${TOKEN_STANDARD.ERC721} only.`,
  )
  .action(setTimestampExpiryAction);

export const withdrawContractBalanceCmd = new Command(
  'withdraw-contract-balance',
)
  .command('withdraw-contract-balance <collection>')
  .description('Withdraws the contract balance to the specified address.')
  .action(withdrawContractBalanceAction);

export const freezeThawContractCmd = new Command('freeze-thaw-contract')
  .command('freeze-thaw-contract <collection>')
  .alias('ftc')
  .alias('freeze-thaw')
  .description(
    `Freeze/Thaw contract. Support for ${TOKEN_STANDARD.ERC1155} only`,
  )
  .addOption(getFreezeThawOption().makeOptionMandatory())
  .action(freezeThawContractAction);

export const transferOwnershipCmd = new Command('transfer-ownership')
  .command('transfer-ownership <collection>')
  .description(
    'Allows the owner to transfer the collection ownership to `newOwner`.',
  )
  .addOption(getNewOwnerOption().makeOptionMandatory())
  .action(transferOwnershipAction);

export const manageAuthorizedMintersCmd = new Command(
  'manage-authorized-minters',
)
  .command('manage-authorized-minters <collection>')
  .alias('mam')
  .alias('manage-minters')
  .description('Add/Remove authorized minters to the collection.')
  .addOption(getMinterOption().makeOptionMandatory())
  .addOption(getMinterActionOption().makeOptionMandatory())
  .action(manageAuthorizedMintersAction);

export const setMintableCmd = new Command('set-mintable')
  .command('set-mintable <collection>')
  .description(
    `Sets mintable for the collection. this will overwrite the existing mintable value. Support for ${TOKEN_STANDARD.ERC721} only.`,
  )
  .addOption(getIsMintableOption())
  .action(setMintableAction);

export const setTokenURISuffixCmd = new Command('set-token-uri-suffix')
  .command('set-token-uri-suffix <collection>')
  .alias('stus')
  .description(
    `Sets the tokenURISuffix for the collection. This will overwrite the existing tokenUriSuffix value. Support for ${TOKEN_STANDARD.ERC721} only.`,
  )
  .addOption(getTokenUriSuffixOption().makeOptionMandatory())
  .action(setTokenUriSuffixAction);

export const ownerMintCmd = new Command('owner-mint')
  .command('owner-mint <collection>')
  .description(
    'Mints token(s) by owner. NOTE: This function bypasses validations thus only available for owner. This is typically used for owner to pre-mint or mint the remaining of the supply.',
  )
  .addOption(getReceiverOption().makeOptionMandatory())
  .addOption(getTokenIdOption())
  .addOption(getQtyOption().makeOptionMandatory())
  .action(ownerMintAction);

export const checkSignerBalanceCmd = new Command('check-signer-balance')
  .command('check-signer-balance <collection>')
  .alias('csb')
  .description('Check the balance of the signer account for the collection.')
  .action(checkSignerBalanceAction);
