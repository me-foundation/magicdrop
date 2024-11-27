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
| ERC721MInitializableV1_0_0  | The initializable implementation for ERC721M.                                      |
| ERC721CMInitializableV1_0_0 | The initializable implementation for ERC721CM.                                     |
| ERC1155MInitializableV1_0_0 | The initializable implementation for ERC1155M.                                     |

## Deployment Address & Salts
| Name                        | Address     | Salt |
|-----------------------------|-------------------------------------------|-----------------------------------------|
| MagicDropTokenImplRegistry | 0x00000000caF1E3978e291c5Fb53FeedB957eC146 |0x78c643228c532b1aee1930fedd4a4b0e6d3d8723987c0809d76a222b0d59b461 |
| MagicDropCloneFactory | 0x000000009e44eBa131196847C685F20Cd4b68aC4 | 0xd8c5a3057ccf31c5fd5cee4e4a5ad9005d0a9a7f4983365010b8785805b44eb1
| ERC721MInitializableV1_0_0 | 0x00000000b55a1126458841Cc756E565C50759484 | 0x4ca859ec4f4daad3d92dcc2959e01718def5eb520350e3e93bd31fc8d2b3beff
| ERC721CMInitializableV1_0_0 | 0x00000000760644De6b7b40362288e944f4154121 | 0x8ae63539ad30ece1889c0999c70b900ffaf0e10ee23b777924c310ad548b6266
| ERC1155MInitializableV1_0_0 | 0x000000009B3dC659D26BD2f3D38136E2b270C28d | 0x8b72ee316ce281e983b3694fc794164ce2eac8c3b8d7751c42edfc89310c6665

### Supported Chains
- Polygon
- Base
- Sei
- Arbitrum
- Apechain

## Using Foundry

### Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
```

### Install Dependencies

```bash
forge install
```

### Build Contracts

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
