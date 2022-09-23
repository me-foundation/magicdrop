## ERC721M

ERC721M is a EVM minting protocol that enables the multi stage minting, per stage WL management, per stage supply limit, and crossmint support.

## Motivation

We'd like to introduce the standard of "minting stages". At each stage, the creators can define the following properties:

- per-stage price
- per-stage walletLimit
- per-stage merkleRoot
- per-stage maxStageSupply

The composability of the stages is generic enough to enable flexible and complicated EVM minting contracts.

![](https://bafkreidwnpgkavfiamg23b6l5ze3r5qjtrn3p5x3rhecunmhw2nhdrkxri.ipfs.nftstorage.link/)


## Build status
![github ci status](https://github.com/magiceden-oss/erc721m/actions/workflows/ci.yml/badge.svg?branch=main)

![npm](https://img.shields.io/npm/v/@magiceden-oss/erc721m?color=green)


## Tech/framework used

<b>Built with</b>
- [hardhat](https://hardhat.org)
- [ERC721A](https://github.com/chiru-labs/ERC721A), ERC721M is based on the popular ERC721A contract.

## Features

- Minting Stages
- Permenent BaseURI Support
- Non-incresing Max Total Supply Support
- Per-stage WL Merkle Tree
- Per-stage Max Supply
- Global and Per-stage Limit
- Native TypeScript and Typechain-Types Support

## Installation
Provide step by step series of examples and explanations about how to get a development env running.


```bash
npm add @magiceden-oss/erc721m
```

## Code Example

```typescript
import { ERC721M, ERC721M__factory } from '@magiceden-oss/erc721m';

const contract = ERC721M__factory.connect(
  contractAddress,
  signerOrProvider,
);
```

## API Reference

```bash
# Compile the contract
npm run build

# Get the auto generated typechain-types
./typechain-types
```

## Tests

```bash
npm run test
```

We are targeting 100% lines coverage.

![](https://bafkreic3dyzp5i2fi7co2fekkbgmyxgv342irjy5zfiuhvjqic6fuu53ju.ipfs.nftstorage.link/)

## Security
- TODO

## Used By

- [Azra Games](https://twitter.com/AzraGames)

## License

MIT © [MagicEden Open Source](https://github.com/magiceden-oss)
