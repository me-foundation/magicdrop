import { TOKEN_STANDARD } from '../constants';
import { showError, showText } from '../display';
import { getProjectStore, getTemplateStore } from '../fileUtils';
import { getChainIdFromName } from '../getters';

const newProjectAction = async (
  collection: string,
  params: { tokenStandard: TOKEN_STANDARD; chain: string },
) => {
  collection = collection.toLowerCase();

  const projectStore = getProjectStore(collection, false, true);

  if (projectStore.exists) {
    showError({ text: `Project ${collection} already exists` });
    process.exit(1);
  }

  const templateStore = getTemplateStore(params.tokenStandard);
  projectStore.data = templateStore.data;

  if (projectStore.data) {
    projectStore.data.chainId = getChainIdFromName(params.chain);
    projectStore.write();
  }

  showText(
    `Successfully set up new project for ${collection}`,
    `path: ${projectStore.root}`,
    true,
  );
  process.exit(0);
};

export default newProjectAction;
