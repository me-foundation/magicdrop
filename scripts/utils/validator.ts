const LIMITBREAK_TRANSFER_VALIDATOR_V3 =
  '0x721C0078c2328597Ca70F5451ffF5A7B38D4E947';
const ME_TRANSFER_VALIDATOR_V3 = '0x721C00D4FB075b22a5469e9CF2440697F729aA13';

export const APPLY_LIST_TO_COLLECTION_ABI = [
  {
    inputs: [
      {
        internalType: 'address',
        name: 'collection',
        type: 'address',
      },
      {
        internalType: 'uint120',
        name: 'id',
        type: 'uint120',
      },
    ],
    name: 'applyListToCollection',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
];

export type TransferValidatorSetting = {
  validatorAddress: string;
  listId: number;
};

// ME owned list id on transfer validator v3
const NETWORK_VALIDATOR_LIST_ID: Record<string, TransferValidatorSetting> = {
  // ME owned listId = 1, 2, 3 on ME owned validator
  'apechain': {
    validatorAddress: ME_TRANSFER_VALIDATOR_V3,
    listId: 1,
  },
  // ME owned listId = 3, 4, 5 on LB owned validator
  'arbitrum': {
    validatorAddress: LIMITBREAK_TRANSFER_VALIDATOR_V3,
    listId: 1,
  },
  // ME owned listId = 1, 2, 3 on LB owned validator
  'base': {
    validatorAddress: LIMITBREAK_TRANSFER_VALIDATOR_V3,
    listId: 1,
  },
  // ME owned listId = 3, 4, 5 on LB owned validator
  'mainnet': {
    validatorAddress: LIMITBREAK_TRANSFER_VALIDATOR_V3,
    listId: 1,
  },
  // ME owned listId = 3, 4, 5 on LB owned validator
  'polygon': {
    validatorAddress: LIMITBREAK_TRANSFER_VALIDATOR_V3,
    listId: 3,
  },
};

export function getTargetListOnValidatorV3(
  network: string,
): TransferValidatorSetting {
  return NETWORK_VALIDATOR_LIST_ID[network];
}
