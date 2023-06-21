// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC721Base.sol";
import "@thirdweb-dev/contracts/eip/interface/IERC20.sol";
import "@erc6551/src/interfaces/IERC6551Registry.sol";
import "@thirdweb-dev/contracts/lib/NFTMetadataRendererLib.sol";

contract MembershipNFT is ERC721Base {
    // TODO get rid of levels & increment instead
    // TODO calculate threshold rather than setting it manually
    // TODO edit comments
    // TODO add events

    event SharedMetadataUpdated(
        uint256 indexed level,
        string indexed name,
        string description,
        string indexed imageURI,
        string animationURI
    );

    /// @notice Token metadata information
    struct TierInfo {
        uint256 threshold;
        SharedMetadataInfo metadata;
        bool exists;
    }

    /**
     *  @notice Structure for metadata shared across all tokens
     *
     *  @param name Shared name of NFT in metadata
     *  @param description Shared description of NFT in metadata
     *  @param imageURI Shared URI of image to render for NFTs
     *  @param animationURI Shared URI of animation to render for NFTs
     */
    struct SharedMetadataInfo {
        string name;
        string description;
        string imageURI;
        string animationURI;
    }

    /// @notice Token metadata information
    mapping(uint256 => TierInfo) public tierURIs;
    address internal implementation;
    address internal tokenContract;
    uint256[] internal levels;
    uint256 internal chainId;
    address internal registryContract;

    constructor(
        string memory _name,
        string memory _symbol,
        address _royaltyRecipient,
        uint128 _royaltyBps,
        address _implementation,
        address _tokenContract,
        uint256 _chainId,
        address _registryContract
    ) ERC721Base(_name, _symbol, _royaltyRecipient, _royaltyBps) {
        implementation = _implementation;
        tokenContract = _tokenContract;
        chainId = _chainId;
        registryContract = _registryContract;
    }

    /// @notice Set shared metadata and threshold balance for a level
    function setSharedMetadata(
        uint256 level,
        uint256 threshold,
        SharedMetadataInfo calldata _metadata
    ) external virtual {
        if (!_canSetSharedMetadata()) {
            revert("Not authorized");
        }
        _setSharedMetadata(level, threshold, _metadata);
    }

    function mintTo(
        address /*_to*/,
        string memory /*_tokenURI*/
    ) public virtual override {
        revert("Cannot call mintTo externally");
    }

    // allow the user to claim the NFT (will be level 0)
    function claim(address _to) public virtual {
        require(_canMint(), "Not authorized to mint.");
        _safeMint(_to, 1, "");
    }

    /**
     *  @notice         Returns the metadata URI for an NFT & works out it's level based on the associated TBA's balance.
     *  @dev            See `BatchMintMetadata` for handling of metadata in this contract.
     *
     *  @param _tokenId The tokenId of an NFT.
     */
    function tokenURI(
        uint256 _tokenId
    ) public view virtual override returns (string memory) {
        uint256 level;
        address wallet = IERC6551Registry(registryContract).account(
            implementation,
            chainId,
            tokenContract,
            _tokenId,
            0
        );
        uint256 balance = IERC20(tokenContract).balanceOf(wallet);
        // do math here if there are multiple levels rather than up to 3
        for (uint i = 0; i < levels.length; i++) {
            if (balance >= tierURIs[levels[i]].threshold) {
                level = levels[i];
            }
        }
        return _getURIFromSharedMetadata(level, _tokenId);
    }

    /**
     *  @dev Sets shared metadata and the threshold balance for an NFT given it's level.
     *  @param _metadata common metadata for all tokens
     */
    function _setSharedMetadata(
        uint256 _level,
        uint256 _threshold,
        SharedMetadataInfo calldata _metadata
    ) internal {
        require(tierURIs[_level].exists == false, "This level already exists");
        SharedMetadataInfo memory levelSharedMetadata = SharedMetadataInfo({
            name: _metadata.name,
            description: _metadata.description,
            imageURI: _metadata.imageURI,
            animationURI: _metadata.animationURI
        });
        tierURIs[_level] = TierInfo(_threshold, levelSharedMetadata, true);
        levels.push(_level);
        emit SharedMetadataUpdated({
            level: _level,
            name: _metadata.name,
            description: _metadata.description,
            imageURI: _metadata.imageURI,
            animationURI: _metadata.animationURI
        });
    }

    /**
     *  @dev Token URI information getter for a given level.
     *  @param level  level to get URI for
     */
    function _getURIFromSharedMetadata(
        uint256 level,
        uint256 tokenId
    ) internal view returns (string memory) {
        SharedMetadataInfo memory info = tierURIs[level].metadata;
        return
            NFTMetadataRenderer.createMetadataEdition({
                name: info.name,
                description: info.description,
                imageURI: info.imageURI,
                animationURI: info.animationURI,
                tokenOfEdition: tokenId
            });
    }

    /// @dev Returns whether shared metadata can be set in the given execution context.
    function _canSetSharedMetadata() internal view virtual returns (bool) {
        return msg.sender == owner();
    }
}
