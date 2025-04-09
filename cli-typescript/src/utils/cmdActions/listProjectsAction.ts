import fs from 'fs';
import path from 'path';
import { COLLECTION_DIR } from '../constants';
import { showError, showText } from '../display';

const listProjectsAction = async () => {
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
    projectList.forEach((project, index) => {
      console.log(`${index + 1}. ${project}`);
    });
  } catch (error: any) {
    showError({
      text: `An error occurred while listing projects: ${error.message}`,
    });
  }
};

export default listProjectsAction;
