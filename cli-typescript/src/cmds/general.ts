import { Command } from 'commander';
import newProjectAction from '../utils/cmdActions/newProjectAction';
import {
  chainOption,
  getForceOption,
  setupWalletOption,
  tokenStandardOption,
} from '../utils/cmdOptions';
import listProjectsAction from '../utils/cmdActions/listProjectsAction';
import { getNewProjectCmdDescription } from '../utils/createCommand';
import newWalletAction from '../utils/cmdActions/newWalletAction';

export const newProjectCmd = new Command('new')
  .command('new <collection>')
  .aliases(['n', 'init'])
  .description(getNewProjectCmdDescription())
  .addOption(chainOption)
  .addOption(tokenStandardOption)
  .addOption(setupWalletOption)
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
