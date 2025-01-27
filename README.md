# MagicDrop

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
| Contract                    | Description                                                                        |
|-----------------------------|------------------------------------------------------------------------------------|
| ERC721M                     | The basic minting contract based on ERC721A.                                       |
| ERC721CM                    | The basic minting contract based on ERC721C and ERC721M.                           |
| ERC1155M                    | The basic minting contract based on ERC1155.                                       |
| MagicDropTokenImplRegistry  | The implementation registry for MagicDrop contracts.                               |
| MagicDropCloneFactory       | The factory contract for cloning MagicDrop contracts.                              |
| ERC721MInitializableV1_0_1  | The initializable implementation for ERC721M.                                      |
| ERC721CMInitializableV1_0_1 | The initializable implementation for ERC721CM.                                     |
| ERC1155MInitializableV1_0_1 | The initializable implementation for ERC1155M.                                     |
| ERC721MagicDropCloneable    | A simple cloneable implementation of ERC721 with public and private stages.        |
| ERC1155MagicDropCloneable   | A simple cloneable implementation of ERC1155 with public and private stages.       |

## Deployment Address & Salts (Non-ZKSync Chains)
| Name                        | Address     | Salt |
|-----------------------------|-------------------------------------------|-----------------------------------------|
| MagicDropTokenImplRegistry | 0x00000000caF1E3978e291c5Fb53FeedB957eC146 |0x78c643228c532b1aee1930fedd4a4b0e6d3d8723987c0809d76a222b0d59b461 |
| MagicDropCloneFactory | 0x000000009e44eBa131196847C685F20Cd4b68aC4 | 0xd8c5a3057ccf31c5fd5cee4e4a5ad9005d0a9a7f4983365010b8785805b44eb1
| ERC721MInitializableV1_0_1 | 0x000000f463fc9825682F484D3D5cDF5Aa6B16f59 | 0x403062abd5dc450d08ecd8aaaa1ec0ddca9c82f127cb4c45f34202ea27b6a4b1
| ERC721CMInitializableV1_0_1 | 0x000000c2b388C25a544258E4d8EEDD31e0E59611 | 0x68e3c267b3ddb63ff8e85f7d593c2e041710a2dd142f07b0c8f5020f46284a22
| ERC1155MInitializableV1_0_1 | 0x000000d076bc17cb89e11825c060d2f329fc9083 | 0x5549e6a920f24bb3665381d9b0174fe9a0337e0eb771ee600da7b0cf1b63fa24
| ERC721MagicDropCloneable    | 0x000000FB0f19714B7B75A73F8484061aCde05bDC | 0xa63b2c7e4254d68d54ef7eb831dec5fb7ac7fd23aa5beb68ae12235abd33823d
| ERC1155MagicDropCloneable   | 0x00000089adfC1a3CAa6A5a6C869E2Dfdd22F7E13 | 0xf8c38b152c86dd9aeafb566f64b579ce3332f118fb6ec058c5e1deecc9f5b7d8

### Abstract Deployed Addresses
| Contract                    | Address     |
|-----------------------------|-------------------------------------------|
| MagicDropTokenImplRegistry  | 0x9b60ad31F145ec7EE3c559153bB57928B65C0F87 |
| MagicDropCloneFactory       | 0x4a08d3F6881c4843232EFdE05baCfb5eAaB35d19 |
| ERC721MInitializableV1_0_1  | 0xb6049C5eaD766E6BBe26F505c01C329B899d8f55 |
| ERC721CMInitializableV1_0_1 | 0x42C25f4165a4310Bd029323dAFc7254546cC97f9 |
| ERC1155MInitializableV1_0_1 | 0x13405abe50EFE5b564B40E1f52F5598C845C4aCD |
| ERC721MagicDropCloneable    | 0xc7E86760d1A533d1251585710F589AFc14A30618 |
| ERC1155MagicDropCloneable   | 0xEC489BC18E4F08f460aff3b4a5dB65e562DA5c32 |


### Supported Chains
- Ethereum
- Polygon
- Base
- Sei
- Arbitrum
- Apechain
- BSC
- Abstract

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
