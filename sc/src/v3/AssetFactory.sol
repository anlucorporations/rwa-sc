// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IIdentityRegistryLight, IIdentityLight} from "./IAssetCompliance.sol";
import {AssetNFT721} from "./AssetNFT721.sol";
import {AssetERC1155} from "./AssetERC1155.sol";

/// @title AssetFactory — despliega y registra activos tokenizados
/// @notice Exige al emisor los claims GARANTÍA (11) y FIADOR (12) antes de crear el activo.
contract AssetFactory is AccessControl {
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    IIdentityRegistryLight public immutable identityRegistry;
    uint256 public guaranteeTopic;
    uint256 public guarantorTopic;

    struct AssetRecord {
        address token;
        address issuer;
        string kind; // product | service | good
        uint256 createdAt;
    }

    AssetRecord[] public assets;
    mapping(address => bool) public isAsset;
    event AssetCreated(address indexed token, address indexed issuer, string kind, uint16 standard);
    event TopicsUpdated(uint256 guaranteeTopic, uint256 guarantorTopic);

    error IssuerNotEligible(address issuer, uint256 topic);

    constructor(address admin_, address identityRegistry_, uint256 guaranteeTopic_, uint256 guarantorTopic_) {
        require(admin_ != address(0), "admin requerido");
        identityRegistry = IIdentityRegistryLight(identityRegistry_);
        guaranteeTopic = guaranteeTopic_;
        guarantorTopic = guarantorTopic_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(CREATOR_ROLE, admin_);
    }

    function setTopics(uint256 guaranteeTopic_, uint256 guarantorTopic_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        guaranteeTopic = guaranteeTopic_;
        guarantorTopic = guarantorTopic_;
        emit TopicsUpdated(guaranteeTopic_, guarantorTopic_);
    }

    /// @notice El emisor debe tener claims GARANTÍA y FIADOR vigentes (fail-closed).
    function isIssuerEligible(address issuer) public view returns (bool) {
        if (address(identityRegistry) == address(0)) return false;
        if (!identityRegistry.isRegistered(issuer)) return false;
        address identity = identityRegistry.getIdentity(issuer);
        if (identity == address(0)) return false;
        return _hasTopic(identity, guaranteeTopic) && _hasTopic(identity, guarantorTopic);
    }

    function _hasTopic(address identity, uint256 topic) internal view returns (bool) {
        address[] memory issuers = IIdentityLight(identity).getClaimIssuersForTopic(topic);
        for (uint256 i = 0; i < issuers.length; i++) {
            if (IIdentityLight(identity).hasValidClaim(topic, issuers[i])) return true;
        }
        return false;
    }

    function _checkIssuer(address issuer) internal view {
        if (!isIssuerEligible(issuer)) revert IssuerNotEligible(issuer, guaranteeTopic);
    }

    function createNFT721(
        string calldata name_,
        string calldata symbol_,
        string calldata kind_,
        address issuer_,
        uint256[] calldata requiredTopics_
    ) external onlyRole(CREATOR_ROLE) returns (address token) {
        _checkIssuer(issuer_);
        token = address(
            new AssetNFT721(name_, symbol_, kind_, issuer_, address(identityRegistry), requiredTopics_)
        );
        _register(token, issuer_, kind_);
        emit AssetCreated(token, issuer_, kind_, 721);
    }

    function createERC1155(
        string calldata uri_,
        string calldata kind_,
        address issuer_,
        uint256[] calldata requiredTopics_
    ) external onlyRole(CREATOR_ROLE) returns (address token) {
        _checkIssuer(issuer_);
        token = address(new AssetERC1155(uri_, kind_, issuer_, address(identityRegistry), requiredTopics_));
        _register(token, issuer_, kind_);
        emit AssetCreated(token, issuer_, kind_, 1155);
    }

    function _register(address token, address issuer, string calldata kind_) internal {
        assets.push(AssetRecord({token: token, issuer: issuer, kind: kind_, createdAt: block.timestamp}));
        isAsset[token] = true;
    }

    function assetsCount() external view returns (uint256) {
        return assets.length;
    }
}
