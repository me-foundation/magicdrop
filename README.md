# MagicDrop

[![NPM][npm-shield]][npm-url]
[![CI][ci-shield]][ci-url]
[![MIT License][license-shield]][license-url]
[![Coverage][coverage-shield]][coverage-url]

MagicDrop is a collection of EVM minting protocols that enable the multi stage minting, per stage WL management, per stage supply limit, and crossmint support.

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
- Crossmint support
- Native TypeScript and Typechain-Types Support

## Contracts
| Contract                | Description                                                                           |
|-------------------------|---------------------------------------------------------------------------------------|
| ERC721M                 | The basic minting contract based on ERC721A.                                          |
| ERC721CM                | The basic minting contract based on ERC721C and ERC721M.                                         |
| ERC721CMRoyalties       | Based on ERC721CM, implementing ERC2981 for on-chain royalty.                         |
| ERC721MOperatorFilterer | ERC721M with OpenSea Operator Filterer                                                |
| BucketAuction           | Bucket auction style minting contract. The contract is on beta. Use at your own risk. |

Please read [ERC721M Contract Usage Guide](./docs/ContractUsageGuide.md) for more details.

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
