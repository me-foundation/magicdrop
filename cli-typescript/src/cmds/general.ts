import { Command } from 'commander';
import newProjectAction from '../utils/cmdActions/newProjectAction';
import {
  chainOption,
  setupSignerOption,
  tokenStandardOption,
} from '../utils/cmdOptions';
import listProjectsAction from '../utils/cmdActions/listProjectsAction';
import { getNewProjectCmdDescription } from '../utils/createCommand';

export const newProjectCmd = new Command('new')
  .command('new <collection>')
  .aliases(['n', 'init'])
  .description(getNewProjectCmdDescription())
  .addOption(chainOption)
  .addOption(tokenStandardOption)
  .addOption(setupSignerOption)
  .action(newProjectAction);

export const listProjectsCmd = new Command('list')
  .alias('ls')
  .description('list all local collections/projects')
  .action(listProjectsAction);
