// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IdentityRegistry} from "../../../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../../../src/TrustedIssuersRegistry.sol";
import {ClaimTopicsRegistryCloneable} from "../../../src/ClaimTopicsRegistryCloneable.sol";
import {BaseHandler} from "./BaseHandler.sol";

/**
 * @title RegistryGhosts
 * @notice Modelo independiente (estado fantasma) de la pertenencia esperada en cada registry.
 *
 * Se actualiza **solo** cuando la llamada al contrato tiene exito. Si el contrato deja el array
 * y el mapping desincronizados, el invariante que compara el contrato con este modelo falla.
 */
contract RegistryGhosts {
    mapping(address => bool) public expectedRegistered;
    mapping(address => bool) public expectedTrusted;
    mapping(uint256 => bool) public expectedTopic;
    /// @dev Contador de acciones con exito (evidencia de que el handler ejercita caminos reales).
    mapping(bytes32 => uint256) public successCount;

    function markRegistered(address wallet, bool value) external {
        expectedRegistered[wallet] = value;
    }

    function markTrusted(address issuer, bool value) external {
        expectedTrusted[issuer] = value;
    }

    function markTopic(uint256 topic, bool value) external {
        expectedTopic[topic] = value;
    }

    function record(bytes32 action) external {
        successCount[action]++;
    }
}

/**
 * @title RegistryHandler
 * @notice Handler con estado para `IdentityRegistry`, `TrustedIssuersRegistry` y
 * `ClaimTopicsRegistryCloneable` (RF-009 / Fase 4). Es `owner` de los tres registries.
 *
 * Ejerce altas, bajas y actualizaciones en cualquier orden sobre pools fijos; cada operacion con
 * exito actualiza el modelo fantasma de `RegistryGhosts`.
 */
contract RegistryHandler is BaseHandler {
    struct Config {
        IdentityRegistry identityRegistry;
        TrustedIssuersRegistry issuersRegistry;
        ClaimTopicsRegistryCloneable topicsRegistry;
        RegistryGhosts ghosts;
    }

    IdentityRegistry private identityRegistry;
    TrustedIssuersRegistry private issuersRegistry;
    ClaimTopicsRegistryCloneable private topicsRegistry;
    RegistryGhosts private ghosts;
    address[] private wallets;
    address[] private identities;
    address[] private issuers;

    constructor(
        Config memory config,
        address[] memory _wallets,
        address[] memory _identities,
        address[] memory _issuers
    ) {
        identityRegistry = config.identityRegistry;
        issuersRegistry = config.issuersRegistry;
        topicsRegistry = config.topicsRegistry;
        ghosts = config.ghosts;
        wallets = _wallets;
        identities = _identities;
        issuers = _issuers;
    }

    // ============ IdentityRegistry ============

    function registerIdentity(uint256 walletSeed, uint256 identitySeed) external {
        address wallet = wallets[walletSeed % wallets.length];
        address identity = identities[identitySeed % identities.length];
        bool ok =
            _call(address(identityRegistry), abi.encodeCall(IdentityRegistry.registerIdentity, (wallet, identity)));
        if (ok) {
            ghosts.markRegistered(wallet, true);
            ghosts.record("registerIdentity");
        }
    }

    function removeIdentity(uint256 walletSeed) external {
        address wallet = wallets[walletSeed % wallets.length];
        bool ok = _call(address(identityRegistry), abi.encodeCall(IdentityRegistry.removeIdentity, (wallet)));
        if (ok) {
            ghosts.markRegistered(wallet, false);
            ghosts.record("removeIdentity");
        }
    }

    function updateIdentity(uint256 walletSeed, uint256 identitySeed) external {
        address wallet = wallets[walletSeed % wallets.length];
        address identity = identities[identitySeed % identities.length];
        // La actualizacion no cambia la pertenencia al array, solo la identidad apuntada.
        bool ok = _call(address(identityRegistry), abi.encodeCall(IdentityRegistry.updateIdentity, (wallet, identity)));
        if (ok) {
            ghosts.record("updateIdentity");
        }
    }

    // ============ TrustedIssuersRegistry ============

    function addTrustedIssuer(uint256 issuerSeed, uint256 topicSeed) external {
        address issuer = issuers[issuerSeed % issuers.length];
        uint256[] memory topics = new uint256[](1);
        topics[0] = _bound(topicSeed, 1, 3);
        bool ok =
            _call(address(issuersRegistry), abi.encodeCall(TrustedIssuersRegistry.addTrustedIssuer, (issuer, topics)));
        if (ok) {
            ghosts.markTrusted(issuer, true);
            ghosts.record("addTrustedIssuer");
        }
    }

    function removeTrustedIssuer(uint256 issuerSeed) external {
        address issuer = issuers[issuerSeed % issuers.length];
        bool ok = _call(address(issuersRegistry), abi.encodeCall(TrustedIssuersRegistry.removeTrustedIssuer, (issuer)));
        if (ok) {
            ghosts.markTrusted(issuer, false);
            ghosts.record("removeTrustedIssuer");
        }
    }

    function updateIssuerClaimTopics(uint256 issuerSeed, uint256 topicSeed) external {
        address issuer = issuers[issuerSeed % issuers.length];
        uint256[] memory topics = new uint256[](1);
        topics[0] = _bound(topicSeed, 1, 3);
        bool ok = _call(
            address(issuersRegistry), abi.encodeCall(TrustedIssuersRegistry.updateIssuerClaimTopics, (issuer, topics))
        );
        if (ok) {
            ghosts.record("updateIssuerClaimTopics");
        }
    }

    // ============ ClaimTopicsRegistryCloneable ============

    function addClaimTopic(uint256 topicSeed) external {
        uint256 topic = _bound(topicSeed, 1, 3);
        bool ok = _call(address(topicsRegistry), abi.encodeCall(ClaimTopicsRegistryCloneable.addClaimTopic, (topic)));
        if (ok) {
            ghosts.markTopic(topic, true);
            ghosts.record("addClaimTopic");
        }
    }

    function removeClaimTopic(uint256 topicSeed) external {
        uint256 topic = _bound(topicSeed, 1, 3);
        bool ok = _call(address(topicsRegistry), abi.encodeCall(ClaimTopicsRegistryCloneable.removeClaimTopic, (topic)));
        if (ok) {
            ghosts.markTopic(topic, false);
            ghosts.record("removeClaimTopic");
        }
    }
}
