export const SET_TRANSFER_VALIDATOR_ABI = {
  inputs: [
    {
      internalType: 'address',
      name: 'transferValidator_',
      type: 'address',
    },
  ],
  name: 'setTransferValidator',
  outputs: [],
  stateMutability: 'nonpayable',
  type: 'function',
} as const;

export const APPLY_LIST_TO_COLLECTION_ABI = {
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
} as const;

export const IS_SETUP_LOCKED_ABI = {
  inputs: [],
  name: 'isSetupLocked',
  outputs: [
    {
      internalType: 'bool',
      name: '',
      type: 'bool',
    },
  ],
  stateMutability: 'view',
  type: 'function',
} as const;

export const SUPPORTS_INTERFACE_ABI = {
  inputs: [
    {
      name: 'interfaceId',
      type: 'bytes4',
      internalType: 'bytes4',
    },
  ],
  name: 'supportsInterface',
  type: 'function',
  stateMutability: 'view',
  outputs: [
    {
      name: '',
      type: 'bool',
      internalType: 'bool',
    },
  ],
} as const;

export const NEW_CONTRACT_INITIALIZED_EVENT_ABI = {
  name: 'NewContractInitialized',
  type: 'event',
  inputs: [
    { name: 'contractAddress', type: 'address' },
    { name: 'creator', type: 'address' },
    { name: 'implId', type: 'uint32' },
    { name: 'standardId', type: 'uint8' },
    { name: 'name', type: 'string' },
    { name: 'symbol', type: 'string' },
  ],
} as const;

export const ERC721mAbis = {
  setup: {
    type: 'function',
    name: 'setup',
    inputs: [
      {
        name: 'config',
        type: 'tuple',
        internalType: 'struct SetupConfig',
        components: [
          {
            name: 'contractURI',
            type: 'string',
            internalType: 'string',
          },
          { name: 'baseURI', type: 'string', internalType: 'string' },
          {
            name: 'maxSupply',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'walletLimit',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'payoutRecipient',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'allowlistStage',
            type: 'tuple',
            internalType: 'struct AllowlistStage',
            components: [
              {
                name: 'price',
                type: 'uint80',
                internalType: 'uint256',
              },
              {
                name: 'mintFee',
                type: 'uint80',
                internalType: 'uint256',
              },
              {
                name: 'walletLimit',
                type: 'uint32',
                internalType: 'uint32',
              },
              {
                name: 'merkleRoot',
                type: 'string',
                internalType: 'bytes32',
              },
              {
                name: 'maxStageSupply',
                type: 'uint24',
                internalType: 'uint24',
              },
              {
                name: 'startTime',
                type: 'uint256',
                internalType: 'uint256',
              },
              {
                name: 'endTime',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'royaltyRecipient',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'royaltyBps',
            type: 'uint96',
            internalType: 'uint96',
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
};

export const ERC115mAbis = {
  setTransferable: {
    inputs: [
      {
        internalType: 'bool',
        name: 'transferable',
        type: 'bool',
      },
    ],
    name: 'setTransferable',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  setup: {
    type: 'function',
    name: 'setup',
    inputs: [
      {
        name: 'config',
        type: 'tuple',
        internalType: 'struct SetupConfig',
        components: [
          { name: 'tokenId', type: 'uint256', internalType: 'uint256' },
          {
            name: 'maxSupply',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'walletLimit',
            type: 'uint256',
            internalType: 'uint256',
          },
          { name: 'baseURI', type: 'string', internalType: 'string' },
          {
            name: 'contractURI',
            type: 'string',
            internalType: 'string',
          },
          {
            name: 'publicStage',
            type: 'tuple',
            internalType: 'struct PublicStage',
            components: [
              {
                name: 'startTime',
                type: 'uint256',
                internalType: 'uint256',
              },
              {
                name: 'endTime',
                type: 'uint256',
                internalType: 'uint256',
              },
              {
                name: 'price',
                type: 'uint256',
                internalType: 'uint256',
              },
            ],
          },
          {
            name: 'allowlistStage',
            type: 'tuple',
            internalType: 'struct AllowlistStage',
            components: [
              {
                name: 'startTime',
                type: 'uint256',
                internalType: 'uint256',
              },
              {
                name: 'endTime',
                type: 'uint256',
                internalType: 'uint256',
              },
              {
                name: 'price',
                type: 'uint256',
                internalType: 'uint256',
              },
              {
                name: 'merkleRoot',
                type: 'bytes32',
                internalType: 'bytes32',
              },
            ],
          },
          {
            name: 'payoutRecipient',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'royaltyRecipient',
            type: 'address',
            internalType: 'address',
          },
          {
            name: 'royaltyBps',
            type: 'uint96',
            internalType: 'uint96',
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
} as const;

export const MagicDropCloneFactoryAbis = {
  createContractDeterministic: {
    type: 'function',
    name: 'createContractDeterministic',
    inputs: [
      { name: 'name', type: 'string', internalType: 'string' },
      { name: 'symbol', type: 'string', internalType: 'string' },
      {
        name: 'standard',
        type: 'uint8',
        internalType: 'enum TokenStandard',
      },
      {
        name: 'initialOwner',
        type: 'address',
        internalType: 'address payable',
      },
      { name: 'implId', type: 'uint32', internalType: 'uint32' },
      { name: 'salt', type: 'bytes32', internalType: 'bytes32' },
    ],
    outputs: [{ name: '', type: 'address', internalType: 'address' }],
    stateMutability: 'payable',
  },
  createContract: {
    type: 'function',
    name: 'createContract',
    inputs: [
      { name: 'name', type: 'string', internalType: 'string' },
      { name: 'symbol', type: 'string', internalType: 'string' },
      {
        name: 'standard',
        type: 'uint8',
        internalType: 'enum TokenStandard',
      },
      {
        name: 'initialOwner',
        type: 'address',
        internalType: 'address payable',
      },
      { name: 'implId', type: 'uint32', internalType: 'uint32' },
    ],
    outputs: [{ name: '', type: 'address', internalType: 'address' }],
    stateMutability: 'payable',
  },
  predictDeploymentAddress: {
    type: 'function',
    name: 'predictDeploymentAddress',
    inputs: [
      {
        name: 'standard',
        type: 'uint8',
        internalType: 'enum TokenStandard',
      },
      { name: 'implId', type: 'uint32', internalType: 'uint32' },
      { name: 'salt', type: 'bytes32', internalType: 'bytes32' },
    ],
    outputs: [{ name: '', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
} as const;

export const MagicDropTokenImplRegistryAbis = {
  getDeploymentFee: {
    type: 'function',
    name: 'getDeploymentFee',
    inputs: [
      {
        name: 'standard',
        type: 'uint8',
        internalType: 'enum TokenStandard',
      },
      { name: 'implId', type: 'uint32', internalType: 'uint32' },
    ],
    outputs: [
      {
        name: 'deploymentFee',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    stateMutability: 'view',
  },
  getMintFee: {
    type: 'function',
    name: 'getMintFee',
    inputs: [
      {
        name: 'standard',
        type: 'uint8',
        internalType: 'enum TokenStandard',
      },
      { name: 'implId', type: 'uint32', internalType: 'uint32' },
    ],
    outputs: [
      {
        name: 'mintFee',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    stateMutability: 'view',
  },
} as const;
