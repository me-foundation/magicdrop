// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./ERC721MC.sol";
import "./OperatorFilter/DefaultOperatorFilterer.sol";
import "./OverworldExtensions/programmable-royalties/MinterCreatorSharedRoyalties.sol";
import "./OverworldExtensions/access/OwnableBasic.sol";

contract ERC721MOperatorFiltererRoyaltySplitter is ERC721MC, DefaultOperatorFilterer, MinterCreatorSharedRoyalties {
    struct CollectionDetails {
        string collectionName;
        string collectionSymbol;
        string tokenURISuffix;
        uint256 maxMintableSupply;
        uint256 globalWalletLimit;
        address cosigner;
        uint64 timestampExpirySeconds;
        uint256 royaltyFeeNumerator;
        uint256 minterShares;
        uint256 creatorShares;
        address creator;
        address paymentSplitterReference;
    }

    constructor(CollectionDetails memory details)
        ERC721MC(
            details.collectionName,
            details.collectionSymbol,
            details.tokenURISuffix,
            details.maxMintableSupply,
            details.globalWalletLimit,
            details.cosigner,
            details.timestampExpirySeconds
        )
        MinterCreatorSharedRoyalties(
            details.royaltyFeeNumerator,
            details.minterShares,
            details.creatorShares,
            details.creator,
            details.paymentSplitterReference
        )
    {}

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override(ERC721A, IERC721A) onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override(ERC721A, IERC721A) onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    
    function safeMint(address to, uint256 quantity) external {
        _safeMint(to, quantity);
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }


    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
        _onBurned(tokenId);
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 0;
    }
    
    //From Limit Break Example ERC721AC royalties example:
    // function _mint(address to, uint256 quantity) internal virtual override {
    //     uint256 nextTokenId = _nextTokenId();

    //     for (uint256 i = 0; i < quantity;) {
    //         _onMinted(to, nextTokenId + i);
            
    //         unchecked {
    //             ++i;
    //         }
    //     }

    //     super._mint(to, quantity);
    // }

    function mint(
        uint32 qty,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes calldata signature
    ) external payable override nonReentrant {

        super._mintInternal(qty, msg.sender, proof, timestamp, signature);
    }
    
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal override {
        super._beforeTokenTransfers(from, to, startTokenId, quantity); //run all the other things that rely on before token transfer here
        if (from == address(0)){ //only for mints
            for (uint256 i = 0; i < quantity;) {
                _onMinted(to, startTokenId + i);
                unchecked {
                    ++i;
                }
            }
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721AC, IERC721A, MinterCreatorSharedRoyaltiesBase) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
