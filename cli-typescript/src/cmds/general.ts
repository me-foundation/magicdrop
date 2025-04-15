import { Command } from 'commander';
import newProjectAction from '../utils/cmdActions/newProjectAction';
import { chainOption, tokenStandardOption } from '../utils/cmdOptions';
import listProjectsAction from '../utils/cmdActions/listProjectsAction';

export const newProjectCmd = new Command('new')
  .command('new <collection>')
  .aliases(['n', 'init'])
  .description(
    `
    Creates a new launchpad/collection template. 
    you can specify the collection directory by setting the "MAGIC_DROP_COLLECTION_DIR" env 
    else it defaults to "./collections" in the project directory.
    You can also specify the chain and token standard to use for the new project.
    The default chain is monad testnet and the default token standard is ERC721.
  `,
  )
  .addOption(chainOption)
  .addOption(tokenStandardOption)
  .action(newProjectAction);

export const listProjectsCmd = new Command('list')
  .alias('ls')
  .description('list all local collections/projects')
  .action(listProjectsAction);
