22# MagicDrop

[![NPM][npm-shield]][npm-url]
[![CI][ci-shield]][ci-url]
[![MIT License][license-shield]][license-url]
[![Coverage][coverage-shield]][coverage-url]

MagicDrop is a collection of EVM minting protocols that enable the multi stage minting, per stage WL management, per stage supply limit, and authorized minter support.

## Motivation

We'd like to introduce the standard of "minting stages". At each stage, the creators can define the following properties:

- per-stage price
- per-stage walletLimit
- per-stage merkleRoot(whitelist)
- per-stage maxStageSupply

The composability of the stages is generic enough to enable flexible and complicated EVM minting contracts.

<p align="center">
<img src="https://bafkreid7sfgi5tycdvbdtobl3mqnwjlrlawdgioaj6vxvtcmmda74doh7q.ipfs.nftstorage.link/" width="50%" >
</p>

## Tech/ Framework

<b>Built with</b>

- [Hardhat](https://hardhat.org)
- [ERC721A](https://github.com/chiru-labs/ERC721A) by Azuki. Fully compliant implementation of IERC721 with significant gas savings for batch minting.
- [ERC721C](https://github.com/limitbreakinc/creator-token-standards) by LimitBreak. Extends ERC721 and add creator-definable transfer security profiles that are the foundation for enforceable, programmable royalties.

## Features

- Minting Stages
- Permenent BaseURI Support
- Non-incresing Max Total Supply Support
- Per-stage whitelist Merkle Tree
- Per-stage Max Supply
- Global and Per-stage Limit
- Authorized minter support
- Native TypeScript and Typechain-Types Support

## Contracts

| Contract                    | Description                                                                  |
| --------------------------- | ---------------------------------------------------------------------------- |
| ERC721M                     | The basic minting contract based on ERC721A.                                 |
| ERC721CM                    | The basic minting contract based on ERC721C and ERC721M.                     |
| ERC1155M                    | The basic minting contract based on ERC1155.                                 |
| MagicDropTokenImplRegistry  | The implementation registry for MagicDrop contracts.                         |
| MagicDropCloneFactory       | The factory contract for cloning MagicDrop contracts.                        |
| ERC721MInitializableV1_0_2  | The initializable implementation for ERC721M.                                |
| ERC721CMInitializableV1_0_2 | The initializable implementation for ERC721CM.                               |
| ERC1155MInitializableV1_0_2 | The initializable implementation for ERC1155M.                               |
| ERC721MagicDropCloneable    | A simple cloneable implementation of ERC721 with public and private stages.  |
| ERC1155MagicDropCloneable   | A simple cloneable implementation of ERC1155 with public and private stages. |

## Deployment Address & Salts (Non-ZKSync Chains)

| Name                                      | Address                                    | Salt                                                               |
| ----------------------------------------- | ------------------------------------------ | ------------------------------------------------------------------ |
| MagicDropTokenImplRegistry Implementation | 0x00000000a5837C1EeD8145A831c8e69C81112da0 | 0x38f7e43d7b4b0493bb35918ede2a002486e822173f68e1c7c4e9a7a9af451ac2 |
| MagicDropTokenImplRegistry Proxy          | 0x000000000e447e71b2EC36CD62048Dd2a1Cd0a57 | 0xc9b080cde9332d8feb50c92fb198b503b9f90ca09a83429194ad8ef8928aca79 |
| MagicDropCloneFactory Implementation      | 0x0000000067502A08Cc4307672A1d4dc48f08a444 | 0x3ad1a60297b1c9e825cdf7e9452a4e9b109c404a4f9f8069e77c6a916096aa0a |
| MagicDropCloneFactory Proxy               | 0x00000000bEa935F8315156894Aa4a45D3c7a0075 | 0xdcb4ae77dc30804459a9a9bcc9bb1a271049553639fdf5c47e4a6a0c3fd97c7b |
| ERC721MInitializableV1_0_2                | 0x00000000df57029C0628F946f37a4CBaa417d1d9 | 0x56c09d9f6a0b39a14e082b2ee9329f2d07e0d2a57900d4d24797d0bb95f521a9 |
| ERC721CMInitializableV1_0_2               | 0x00000000E7aEc12181Cb4C1D8474634e3fCEe456 | 0x958674b386d1433f28e925ecd473b9ff8ca9cf8b1d4e5a0f417a1d731da7c565 |
| ERC1155MInitializableV1_0_2               | 0x0000000055E6c029AD855Af4a30a0f0fA73b6c5E | 0xab66c31281be63f79c25e30ef51a6293b25eea4a86beb47b323525497c4612af |
| ERC721MagicDropCloneable                  | 0x000000002A1351440079144BF9e40869092576f1 | 0x802853f87f3efa7109bd4a3b7b9ac3daf75f98a3fc97a8fce04d8c17ed2e85c7 |
| ERC1155MagicDropCloneable                 | 0x00000000b03D92E78432FB3377A171655Afdb5bb | 0x0b6a866fa283524661d3b4a0f7f5b85636819e32e1384b395d5454edc7d9299a |

### Abstract Deployed Addresses

| Contract                    | Address                                    |
| --------------------------- | ------------------------------------------ |
| MagicDropTokenImplRegistry  | 0x17c9921D99c1Fa6d3dC992719DA1123dCb2CaedA |
| MagicDropCloneFactory       | 0x01c1C2f5271aDeA338dAfba77121Fc20B5176620 |
| ERC721MInitializableV1_0_2  | 0x92578FCA9eaBEe0f5Bb3E5ea8e291612B75C8748 |
| ERC721CMInitializableV1_0_2 | 0x96e5Ed4446E7652C4306290099C6760fA2332EeC |
| ERC1155MInitializableV1_0_2 | 0x3Cd56fB82B34Bf4AD8f94c29EeDDB7bC132E41De |
| ERC721MagicDropCloneable    | 0xd929CE55a5Ea307FED843E145aFbcC261e2691d8 |
| ERC1155MagicDropCloneable   | 0xDb56d1512C0E885B9b1Ddf704eA83C82654a5B61 |

### Supported Chains

- Ethereum
- Polygon
- Base
- Sei
- Arbitrum
- Apechain
- BSC
- Abstract
- Berachain
- Monad Testnet
- Avalanche

## Using Foundry

### Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

#### For Abstract, install Foundry ZKSync

```bash
curl -L https://raw.githubusercontent.com/matter-labs/foundry-zksync/main/install-foundry-zksync | bash
foundryup-zksync
```

### Install Dependencies

```bash
forge install
```

### Build Contracts

Note: For Abstract, use the `--zksync` flag.

```bash
forge build
```

### Run Tests

```bash
forge test
```

### Install CLI-Typescript

```bash
npm run setup:magicdrop2
```

### Generate Coverage Report

This project includes a script to generate and view a test coverage report. The script is located at `test/generate-coverage-report.sh`.

```bash
./test/generate-coverage-report.sh
```

## Security

- [ERC721M Kudelski Security Audit](./docs/AUDIT-PUBLIC-RELEASE-MagicEden-ERC721M1.pdf)

### Bounty Program

- HackerOne program: please contact https://magiceden.io/.well-known/security.txt
- Please be noted that there are some prerequites need to be met and certain assumptions are made when using the contracts. Please check the [Contract Usage Guide](./docs/ContractUsageGuide.md) for more details.

## Used By

- [Magic Eden Launchpad](https://magiceden.io/launchpad/about)

## License

MIT © [MagicEden Open Source](https://github.com/magiceden-oss)

<!-- MARKDOWN LINKS & IMAGES -->

[ci-shield]: https://img.shields.io/github/actions/workflow/status/magiceden-oss/erc721m/ci.yml?label=build&style=for-the-badge&branch=main
[ci-url]: https://github.com/magiceden-oss/erc721m/actions/workflows/run_tests.yml
[npm-shield]: https://img.shields.io/npm/v/@magiceden-oss/erc721m.svg?style=for-the-badge
[npm-url]: https://www.npmjs.com/package/@magiceden-oss/erc721m
[license-shield]: https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge
[license-url]: https://github.com/magiceden-oss/erc721m/blob/main/LICENSE.txt
[coverage-shield]: https://img.shields.io/codecov/c/gh/magicoss/erc721m?style=for-the-badge
[coverage-url]: https://codecov.io/gh/magicoss/erc721m
