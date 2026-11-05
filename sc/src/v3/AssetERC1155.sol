// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {AssetComplianceHook} from "./AssetComplianceHook.sol";
import {IIdentityRegistryLight} from "./IAssetCompliance.sol";

/// @title AssetERC1155 — productos/lotes por cantidad
contract AssetERC1155 is ERC1155, AccessControl, AssetComplianceHook {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string public assetKind;
    uint256 public nextTokenId = 1;
    mapping(address => bool) public escrowOperators;

    event EscrowOperatorSet(address indexed operator, bool allowed);

    event AssetMinted(address indexed to, uint256 indexed tokenId, uint256 amount);

    constructor(
        string memory uri_,
        string memory assetKind_,
        address admin_,
        address identityRegistry_,
        uint256[] memory requiredTopics_
    ) ERC1155(uri_) {
        require(admin_ != address(0), "admin requerido");
        assetKind = assetKind_;
        identityRegistry = IIdentityRegistryLight(identityRegistry_);
        _setRequiredTopics(requiredTopics_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MINTER_ROLE, admin_);
    }

    function setEscrowOperator(address operator, bool allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        escrowOperators[operator] = allowed;
        emit EscrowOperatorSet(operator, allowed);
    }

    function mint(address to, uint256 tokenId, uint256 amount, bytes calldata data)
        external
        onlyRole(MINTER_ROLE)
    {
        _requireEligible(to);
        _mint(to, tokenId, amount, data);
        emit AssetMinted(to, tokenId, amount);
    }

    function mintNew(address to, uint256 amount, bytes calldata data)
        external
        onlyRole(MINTER_ROLE)
        returns (uint256 tokenId)
    {
        tokenId = nextTokenId++;
        _requireEligible(to);
        _mint(to, tokenId, amount, data);
        emit AssetMinted(to, tokenId, amount);
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override
    {
        // Solo se exime la ENTRADA al escrow; la entrega final al usuario siempre se verifica.
        if (from != address(0) && to != address(0) && !escrowOperators[to]) {
            _requireEligible(to);
        }
        super._update(from, to, ids, values);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
