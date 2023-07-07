//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";
import "./IERC721M.sol";
import "./ERC721MCore.sol";
import "./IERC721MCore.sol";

/**
 * @title ERC721M
 *
 * @dev ERC721A subclass with MagicEden launchpad features including
 *  - multiple minting stages with time-based auto stage switch
 *  - global and stage wallet-level minting limit
 *  - whitelist using merkle tree
 *  - crossmint support
 *  - anti-botting
 */
contract ERC721M is ERC721MCore, IERC721M {

    // Whether base URI is permanent. Once set, base URI is immutable.
    bool private _baseURIPermanent;

    // The crossmint address. Need to set if using crossmint.
    address private _crossmintAddress;

    // Global wallet limit, across all stages.
    uint256 private _globalWalletLimit;

    constructor(
        string memory collectionName,
        string memory collectionSymbol,
        string memory tokenURISuffix,
        uint256 maxMintableSupply,
        uint256 globalWalletLimit,
        address cosigner,
        uint64 timestampExpirySeconds
    ) ERC721MCore(collectionName, collectionSymbol, tokenURISuffix, maxMintableSupply, cosigner, timestampExpirySeconds) {
        if (globalWalletLimit > maxMintableSupply)
            revert GlobalWalletLimitOverflow();
        _maxMintableSupply = maxMintableSupply;
        _globalWalletLimit = globalWalletLimit;
    }

    /**
     * @dev Returns cosigner address.
     */
    function getCosigner() external view override returns (address) {
        return _cosigner;
    }

    /**
     * @dev Sets cosigner.
     */
    function setCosigner(address cosigner) external onlyOwner {
        _cosigner = cosigner;
        emit SetCosigner(cosigner);
    }

    /**
     * @dev Returns expiry in seconds.
     */
    function getTimestampExpirySeconds() external view override returns (uint64) {
        return _timestampExpirySeconds;
    }

    /**
     * @dev Sets expiry in seconds. This timestamp specifies how long a signature from cosigner is valid for.
     */
    function setTimestampExpirySeconds(uint64 expiry) external onlyOwner {
        _timestampExpirySeconds = expiry;
        emit SetTimestampExpirySeconds(expiry);
    }

    /**
     * @dev Returns crossmint address.
     */
    function getCrossmintAddress() external view override returns (address) {
        return _crossmintAddress;
    }

    /**
     * @dev Sets crossmint address if using crossmint. This allows the specified address to call `crossmint`.
     */
    function setCrossmintAddress(address crossmintAddress) external onlyOwner {
        _crossmintAddress = crossmintAddress;
        emit SetCrossmintAddress(crossmintAddress);
    }

    /**
     * @dev Returns global wallet limit. This is the max number of tokens can be minted by one wallet.
     */
    function getGlobalWalletLimit() external view override(ERC721MCore, IERC721MCore) returns (uint256) {
        return _globalWalletLimit;
    }

    /**
     * @dev Sets global wallet limit.
     */
    function setGlobalWalletLimit(uint256 globalWalletLimit)
        external
        onlyOwner
    {
        if (globalWalletLimit > _maxMintableSupply)
            revert GlobalWalletLimitOverflow();
        _globalWalletLimit = globalWalletLimit;
        emit SetGlobalWalletLimit(globalWalletLimit);
    }

    /**
     * @dev Mints token(s) through crossmint. This function is supposed to be called by crossmint.
     *
     * qty - number of tokens to mint
     * to - the address to mint tokens to
     * proof - the merkle proof generated on client side. This applies if using whitelist.
     * timestamp - the current timestamp
     * signature - the signature from cosigner if using cosigner.
     */
    function crossmint(
        uint32 qty,
        address to,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes calldata signature
    ) external payable nonReentrant {
        if (_crossmintAddress == address(0)) revert CrossmintAddressNotSet();

        // Check the caller is Crossmint
        if (msg.sender != _crossmintAddress) revert CrossmintOnly();

        _mintInternal(qty, to, proof, timestamp, signature);
    }

    /**
     * @dev Sets token base URI.
     */
    function setBaseURI(string calldata baseURI) external override(ERC721MCore) onlyOwner {
        if (_baseURIPermanent) revert CannotUpdatePermanentBaseURI();
        _currentBaseURI = baseURI;
        emit SetBaseURI(baseURI);
    }

    /**
     * @dev Sets token base URI permanent. Cannot revert.
     */
    function setBaseURIPermanent() external onlyOwner {
        _baseURIPermanent = true;
        emit PermanentBaseURI(_currentBaseURI);
    }

    /**
     * @dev Returns token URI suffix.
     */
    function getTokenURISuffix() external view override returns (string memory) {
        return _tokenURISuffix;
    }

    /**
     * @dev Returns the current active stage based on timestamp.
     */
    function getActiveStageFromTimestamp(uint64 timestamp)
        external
        view
        override
        returns (uint256)
    {
        return _getActiveStageFromTimestamp(timestamp);
    }
}
