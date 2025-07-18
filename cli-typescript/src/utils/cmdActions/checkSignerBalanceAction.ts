import { actionPresets } from './common';
import { showError } from '../display';

export const checkSignerBalanceAction = async (collection: string) => {
  try {
    await actionPresets(collection, false);
  } catch (error: any) {
    showError({ text: `Error checking signer balance: ${error.message}` });
  }
};
