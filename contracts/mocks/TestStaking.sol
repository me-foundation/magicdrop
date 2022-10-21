//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract TestStaking {
    using EnumerableSet for EnumerableSet.UintSet;
    IERC721A private _nft;
    mapping(address => EnumerableSet.UintSet) private _stakers;

    constructor(address nft) {
        _nft = IERC721A(nft);
    }

    function isStaked(address staker, uint256 tokenId)
        public
        view
        returns (bool)
    {
        return _stakers[staker].contains(tokenId);
    }

    function stake(uint256 tokenId) public {
        _nft.transferFrom(msg.sender, address(this), tokenId);
        _stakers[msg.sender].add(tokenId);
    }

    function stakeTokensFor(address staker, uint256[] calldata tokenIds)
        public
    {
        require(
            msg.sender == address(_nft),
            "Only NFT contract can stake on behalf"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _nft.transferFrom(staker, address(this), tokenIds[i]);
            _stakers[staker].add(tokenIds[i]);
        }
    }

    function stakeFor(address staker, uint256 tokenId) public {
        require(
            msg.sender == address(_nft),
            "Only NFT contract can stake on behalf"
        );
        _nft.transferFrom(staker, address(this), tokenId);
        _stakers[staker].add(tokenId);
    }

    function unstake(uint256 tokenId) public {
        require(_stakers[msg.sender].contains(tokenId), "Not staked");
        _nft.transferFrom(address(this), msg.sender, tokenId);
        _stakers[msg.sender].remove(tokenId);
    }
}
