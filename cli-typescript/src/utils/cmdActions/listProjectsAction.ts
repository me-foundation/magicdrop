import fs from 'fs';
import path from 'path';
import { COLLECTION_DIR } from '../constants';
import { showError, showText } from '../display';
import { EvmPlatform } from '../evmUtils';
import { getProjectStore } from '../fileUtils';

const listProjectsAction = async (platform?: EvmPlatform) => {
  try {
    const projectDir = `${COLLECTION_DIR}/projects`;

    if (!fs.existsSync(projectDir)) {
      throw new Error(
        'No projects found. The project directory does not exist.',
      );
    }

    const projects = fs.readdirSync(projectDir);

    // Filter out non-directory entries
    const projectList = projects.filter((project) =>
      fs.statSync(path.join(projectDir, project)).isDirectory(),
    );

    if (projectList.length === 0) {
      showText('No projects found in the project directory.');
      return;
    }

    showText('Available Projects:', '', false, false);
    let count = 0;
    projectList.forEach((project) => {
      // load the project with store
      const store = getProjectStore(project, true);
      try {
        store.read();
      } catch {}
      // if platform is provided, check if the project is for that platform
      if (
        !store.data?.chainId ||
        !platform ||
        platform.isChainIdSupported(store.data?.chainId ?? 0)
      ) {
        console.log(`${(count += 1)}. ${project}`);
      }
    });

    if (count === 0) showText('No project found!', '', false, false);
  } catch (error: any) {
    showError({
      text: `An error occurred while listing projects: ${error.message}`,
    });
  }
};

export default listProjectsAction;
