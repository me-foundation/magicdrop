import { Command } from 'commander';
import newProjectAction from '../utils/cmdActions/newProjectAction';
import { tokenStandardOption } from '../utils/cmdOptions';
import listProjectsAction from '../utils/cmdActions/listProjectsAction';

export const newProjectCmd = new Command('new <collection>')
  .description(
    `
    creates a new launchpad/collection template. 
    you can specify the collection directory by setting the "MAGIC_DROP_COLLECTION_DIR" env 
    else it defaults to "$HOME/.config/magicdrop"
  `,
  )
  .addOption(tokenStandardOption)
  .action(newProjectAction);

export const listProjectsCmd = new Command('list')
  .alias('ls')
  .description('list all local collections/projects')
  .action(listProjectsAction);
