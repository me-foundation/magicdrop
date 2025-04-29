import { actionPresets } from './common';
import { showError } from '../display';

export const checkSignerBalanceAction = async (collection: string) => {
  try {
    await actionPresets(collection, false);
  } catch (error: any) {
    showError({ text: `Error setting expiry: ${error.message}` });
  }
};
