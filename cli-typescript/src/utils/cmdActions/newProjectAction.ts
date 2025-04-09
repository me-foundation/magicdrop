import { TOKEN_STANDARD } from '../constants';
import { showError, showText } from '../display';
import { getProjectStore, getTemplateStore } from '../fileUtils';

const newProjectAction = async (
  collection: string,
  params: { tokenStandard: TOKEN_STANDARD },
) => {
  collection = collection.toLowerCase();

  const projectStore = getProjectStore(collection);

  if (projectStore.exists) {
    showError({ text: `Project ${collection} already exists` });
    process.exit(1);
  }

  const templateStore = getTemplateStore(params.tokenStandard);
  projectStore.data = templateStore.data;
  projectStore.write();

  showText(
    `Successfully set up new project for ${collection}`,
    `path: ${projectStore.root}`,
    true,
  );
  process.exit(0);
};

export default newProjectAction;
