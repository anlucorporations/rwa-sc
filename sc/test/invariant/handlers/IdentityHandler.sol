// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IdentityCloneable} from "../../../src/IdentityCloneable.sol";
import {SigUtils} from "../../helpers/SigUtils.sol";
import {BaseHandler} from "./BaseHandler.sol";

/**
 * @title IdentityGhosts
 * @notice Estado fantasma de la suite de claims: maximo `claimNonce` observado por
 * `(identidad, topic)` y violaciones de las propiedades de llamada.
 */
contract IdentityGhosts {
    mapping(address => mapping(uint256 => uint256)) public maxNonce;
    bool public revokeUnauthorizedViolated;
    /// @dev Contador de acciones con exito (evidencia de que el handler ejercita caminos reales).
    mapping(bytes32 => uint256) public successCount;

    function observeNonce(address identity, uint256 topic, uint256 nonce) external {
        if (nonce > maxNonce[identity][topic]) {
            maxNonce[identity][topic] = nonce;
        }
    }

    function markRevokeUnauthorized() external {
        revokeUnauthorizedViolated = true;
    }

    function record(bytes32 action) external {
        successCount[action]++;
    }
}

/**
 * @title IdentityHandler
 * @notice Handler con estado para `IdentityCloneable` y el ciclo de vida del claim
 * (RF-009 / Fase 4, CU-17).
 *
 * Acciones: alta/renovacion (firmada EIP-712 con el `claimNonce` vigente), baja por el titular,
 * revocacion por el issuer, intento de revocacion por terceros y avance del reloj. Tras cada
 * accion se observa el `claimNonce` de todas las identidades para detectar decrementos.
 */
contract IdentityHandler is BaseHandler {
    struct Config {
        IdentityCloneable[] identities;
        address identityOwner;
        address issuer;
        uint256 issuerPk;
        uint256[] topics;
        IdentityGhosts ghosts;
    }

    IdentityCloneable[] private identities;
    address private identityOwner;
    address private issuer;
    uint256 private issuerPk;
    uint256[] private topics;
    IdentityGhosts private ghosts;
    address[] private nonIssuerCallers;

    constructor(Config memory config, address[] memory _nonIssuerCallers) {
        identities = config.identities;
        identityOwner = config.identityOwner;
        issuer = config.issuer;
        issuerPk = config.issuerPk;
        topics = config.topics;
        ghosts = config.ghosts;
        nonIssuerCallers = _nonIssuerCallers;
    }

    function addClaim(uint256 identitySeed, uint256 topicSeed, uint256 expiresAtSeed) external {
        IdentityCloneable identity = identities[identitySeed % identities.length];
        uint256 topic = topics[topicSeed % topics.length];

        uint256 expiresAt = _resolveExpiry(expiresAtSeed);
        bytes memory data = abi.encode(topic, address(identity));
        uint256 nonce = identity.claimNonce(topic, issuer);
        bytes memory signature =
            SigUtils.signClaim(issuerPk, address(identity), identityOwner, topic, 1, data, expiresAt, nonce);

        vm.prank(identityOwner);
        bool ok = _call(
            address(identity),
            abi.encodeCall(IdentityCloneable.addClaim, (topic, 1, issuer, signature, data, "", expiresAt))
        );
        if (ok) {
            ghosts.record("addClaim");
        }
        _observeAll(identity);
    }

    function removeClaim(uint256 identitySeed, uint256 topicSeed) external {
        IdentityCloneable identity = identities[identitySeed % identities.length];
        uint256 topic = topics[topicSeed % topics.length];
        vm.prank(identityOwner);
        bool ok = _call(address(identity), abi.encodeCall(IdentityCloneable.removeClaim, (topic, issuer)));
        if (ok) {
            ghosts.record("removeClaim");
        }
        _observeAll(identity);
    }

    function revokeClaim(uint256 identitySeed, uint256 topicSeed) external {
        IdentityCloneable identity = identities[identitySeed % identities.length];
        uint256 topic = topics[topicSeed % topics.length];
        vm.prank(issuer);
        bool ok = _call(address(identity), abi.encodeCall(IdentityCloneable.revokeClaim, (topic, issuer)));
        if (ok) {
            ghosts.record("revokeClaim");
        }
        _observeAll(identity);
    }

    /// @dev Intenta revocar desde una cuenta que **no** es el issuer. Si tuviera exito, seria una
    /// violacion de "revokeClaim siempre exige el issuer" (CU-17 A17.3).
    function revokeClaimFromNonIssuer(uint256 identitySeed, uint256 topicSeed, uint256 callerSeed) external {
        IdentityCloneable identity = identities[identitySeed % identities.length];
        uint256 topic = topics[topicSeed % topics.length];
        address caller = nonIssuerCallers[callerSeed % nonIssuerCallers.length];
        if (caller == issuer) {
            return;
        }
        vm.prank(caller);
        (bool ok,) = address(identity).call(abi.encodeCall(IdentityCloneable.revokeClaim, (topic, issuer)));
        if (ok) {
            ghosts.markRevokeUnauthorized();
        }
        _observeAll(identity);
    }

    function warpTime(uint256 secondsForward) external {
        vm.warp(block.timestamp + _bound(secondsForward, 0, 365 days));
    }

    // ============ Helpers ============

    /// @dev D-038: `0` = sin caducidad; el resto se reparte entre marcas futuras y ya vencidas.
    function _resolveExpiry(uint256 seed) private view returns (uint256) {
        uint256 mode = seed % 3;
        if (mode == 0) {
            return 0;
        }
        if (mode == 1) {
            return block.timestamp + _bound(seed, 0, 365 days);
        }
        return block.timestamp == 0 ? 0 : block.timestamp - 1;
    }

    function _observeAll(IdentityCloneable identity) private {
        for (uint256 i = 0; i < topics.length; i++) {
            ghosts.observeNonce(address(identity), topics[i], identity.claimNonce(topics[i], issuer));
        }
    }
}
