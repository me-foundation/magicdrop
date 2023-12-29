# ERC721M Contract Usage Guide
## Pre-requisites
- To safely use the contract, you need to have a good understanding of the [ERC721](https://eips.ethereum.org/EIPS/eip-721) standard.
- To use ERC-20 payment feature, you need to have a good understanding of the [ERC20](https://eips.ethereum.org/EIPS/eip-20) standard.
- To use the whitelist feature, you need to have a good understanding of the [Merkle Tree](https://en.wikipedia.org/wiki/Merkle_tree) and [Merkle Proof](https://en.wikipedia.org/wiki/Merkle_tree#Merkle_proofs) concepts.
- To use OpenSea's Operator Filterer feature, you need to have a good understanding of the [Operator Filter Registry](https://github.com/ProjectOpenSea/operator-filter-registry).

## Assumptions
- The owner of the contract is assumed to be a trusted party. The contract applies limited validation on the owner's actions. For example, the owner can set the `baseURI` to an invalid value, which will cause NFTs miss the metadata.
- The contract is designed to work with MagicEden Launchpad or in similar minting form. See [Basic Minting Workflow](#basic-minting-workflow) for more details.

## Basic Minting Workflow
The basic minting workflow is as follows. The individual contract may have different minting workflow. Please check the contract's documentation for more details.
  - The owner of the contract deploys the contract and configures the contract such as `baseURI`, `stages`, `mintable` etc.
  - Optinally, the owner is able to pre-mint some NFTs and airdrop them to certain addresses.
  - Minting starts when the first stage starts. Eligible users can mint NFTs by calling `mint` function.
  - Optionally, during the minting, the owner can update stages, pause/unpause minting, update supply etc.
  - Minting closes when the last stage ends or the `maxTotalSupply` is reached.
  - Optinally, the owner can perform post-minting actions such as transfering the ownership of the contract, withdraw minting fund, updating `baseURI` to a permenent value etc.
