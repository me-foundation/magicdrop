import { Hex } from 'viem';
import axios, { AxiosInstance } from 'axios';
import { SUPPORTED_CHAINS } from './constants';

export const getProjectSigner = async (
  projectName: string,
): Promise<{ signer: Hex }> => {
  try {
    const { address } =
      await getMETurnkeyServiceClient().getWallet(projectName);

    // Return the signer/address
    return {
      signer: address as Hex,
    };
  } catch (error: any) {
    throw new Error(`Failed to fetch signer: ${error.message}`);
  }
};

export type WalletInfo = {
  walletId: string;
  address: string;
  subOrgId: string;
};

class METurnkeyServiceClient {
  constructor(private readonly client: AxiosInstance) {}

  async createWallet(collectionName: string): Promise<WalletInfo> {
    const response = await this.client.post<{
      data: WalletInfo;
      errors?: any[];
    }>('/create-wallet', { collectionName });

    if (response.data.errors?.length) {
      console.error(response.data.errors);
      throw new Error(
        `Failed to create wallet: ${response.data.errors
          .map((error) => error.message)
          .join(', ')}`,
      );
    }

    return response.data.data;
  }

  async getWallet(collectionName: string): Promise<WalletInfo> {
    const response = await this.client.get<{
      data: WalletInfo;
      errors?: any[];
    }>(`/get-wallet-info/${collectionName}`);

    if (response.data.errors?.length) {
      console.error(response.data.errors);
      throw new Error(
        `Failed to get wallet: ${response.data.errors
          .map((error: any) => error.message)
          .join(', ')}`,
      );
    }

    return response.data.data;
  }

  async sendTransaction(
    collectionName: string,
    transaction: {
      to: Hex;
      data: Hex;
      chainId: SUPPORTED_CHAINS;
      value?: bigint;
      gasLimit?: bigint;
    },
  ): Promise<Hex> {
    const response = await this.client.post<{
      data: { txHash: Hex };
      errors?: any[];
    }>('/send-transaction', {
      collectionName,
      tx: {
        ...transaction,
        value: transaction.value?.toString(),
        gasLimit: transaction.gasLimit?.toString(),
      },
    });
    if (response.data.errors?.length) {
      console.error(response.data.errors);
      throw new Error(
        `Failed to send transaction: ${response.data.errors
          .map((error: any) => error.message)
          .join(', ')}`,
      );
    }
    return response.data.data.txHash;
  }
}

let meTurnkeyServiceClientInstance: METurnkeyServiceClient | null = null;

/**
 * Returns a singleton instance of METurnkeyServiceClient.
 * Ensures only one instance is created and reused.
 */
export const getMETurnkeyServiceClient = (): METurnkeyServiceClient => {
  if (!meTurnkeyServiceClientInstance) {
    const client = axios.create({
      baseURL: `${process.env.ME_TURNKEY_SERVICE_BASE_URL}/v1/turnkey-service/magicdrop`,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    meTurnkeyServiceClientInstance = new METurnkeyServiceClient(client);
  }
  return meTurnkeyServiceClientInstance;
};
