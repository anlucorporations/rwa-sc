// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {AssetComplianceHook} from "./AssetComplianceHook.sol";
import {IIdentityRegistryLight} from "./IAssetCompliance.sol";

/// @title AssetNFT721 — bienes (1 NFT único) y servicios (NFT quemable)
/// @notice Acuñación por rol, transferencias solo a wallets elegibles (B6) y quema del titular.
contract AssetNFT721 is ERC721, ERC721URIStorage, AccessControl, AssetComplianceHook {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 private _nextTokenId = 1;
    mapping(uint256 => bool) public serviceAsset;
    string public assetKind;

    event AssetMinted(address indexed to, uint256 indexed tokenId, string uri);
    event ServiceConsumed(address indexed holder, uint256 indexed tokenId);

    constructor(
        string memory name_,
        string memory symbol_,
        string memory assetKind_,
        address admin_,
        address identityRegistry_,
        uint256[] memory requiredTopics_
    ) ERC721(name_, symbol_) {
        require(admin_ != address(0), "admin requerido");
        assetKind = assetKind_;
        identityRegistry = IIdentityRegistryLight(identityRegistry_);
        _setRequiredTopics(requiredTopics_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MINTER_ROLE, admin_);
    }

    function mint(address to, string calldata uri_, bool isService) external onlyRole(MINTER_ROLE) returns (uint256 tokenId) {
        _requireEligible(to);
        tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri_);
        serviceAsset[tokenId] = isService;
        emit AssetMinted(to, tokenId, uri_);
    }

    /// @notice Consumo de un servicio: el titular quema su NFT (CU-25).
    function consumeService(uint256 tokenId) external {
        require(serviceAsset[tokenId], "no es servicio");
        require(ownerOf(tokenId) == msg.sender, "solo el titular");
        _burn(tokenId);
        emit ServiceConsumed(msg.sender, tokenId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address from) {
        from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            _requireEligible(to);
        }
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
}
