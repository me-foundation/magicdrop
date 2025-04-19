import { TOKEN_STANDARD } from '../constants';
import { showError, showText } from '../display';
import { getProjectStore, getTemplateStore } from '../fileUtils';
import { getChainIdFromName } from '../getters';
import { createProjectSigner } from '../turnkey';

const newProjectAction = async (
  collection: string,
  params: {
    tokenStandard: TOKEN_STANDARD;
    chain: string;
    setupSigner: boolean;
  },
) => {
  collection = collection.toLowerCase();
  console.log(params);

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

  let walletFilePath = 'N/A';
  let signer = undefined;
  // Create a signer for the project
  if (params.setupSigner) {
    const res = await createProjectSigner(collection);
    walletFilePath = res.walletFilePath;
    signer = res.signer;
  }

  const signerInfo = params.setupSigner
    ? `Note: A signer account: ${signer?.address} was created for this collection, you will need to fund it before you can deploy this collection.`
    : `Note: A signer account was NOT setup for this collection, you will need to do that manually before you can deploy it.
      You can do this by creating a wallet.json file in the directory: ${projectStore.storeDir}.`;

  showText(
    `Successfully set up new project for ${collection}`,
    `
    path: ${projectStore.root}
    wallet: ${walletFilePath}

    ${signerInfo}
    `,
    true,
  );
};

export default newProjectAction;
