// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenCloneable} from "../../src/TokenCloneable.sol";
import {TokenCloneFactory} from "../../src/TokenCloneFactory.sol";
import {IdentityCloneable} from "../../src/IdentityCloneable.sol";
import {IdentityCloneFactory} from "../../src/IdentityCloneFactory.sol";
import {IdentityRegistry} from "../../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../../src/TrustedIssuersRegistry.sol";
import {ClaimTopicsRegistry} from "../../src/ClaimTopicsRegistry.sol";
import {SigUtils} from "../helpers/SigUtils.sol";
import {IdentityGhosts, IdentityHandler} from "./handlers/IdentityHandler.sol";

/**
 * @title IdentityInvariantsTest
 * @notice Invariantes con estado del ciclo de vida del claim en `IdentityCloneable`
 * (RF-009 / Fase 4, CU-17).
 *
 * Cubre: `claimNonce` solo crece; `hasValidClaim` es exactamente "existe y no revocado y no
 * vencido"; un claim revocado o vencido nunca verifica; `revokeClaim` solo lo acepta el issuer;
 * y `isVerified` del token equivale a tener un claim vigente de un issuer autorizado por topic.
 */
contract IdentityInvariantsTest is Test {
    TokenCloneable internal token;
    IdentityCloneFactory internal identityFactory;
    IdentityRegistry internal identityRegistry;
    TrustedIssuersRegistry internal trustedIssuersRegistry;
    ClaimTopicsRegistry internal claimTopicsRegistry;

    IdentityGhosts internal ghosts;
    IdentityHandler internal handler;

    address internal admin = address(this);
    address internal issuer;
    uint256 internal constant ISSUER_PK = 0xB0B;
    uint256 internal constant KYC_TOPIC = 1;
    uint256 internal constant AML_TOPIC = 2;

    address[] internal actors;
    IdentityCloneable[] internal identities;
    uint256[] internal claimTopicsPool;

    function setUp() public {
        issuer = vm.addr(ISSUER_PK);

        TokenCloneFactory tokenFactory = new TokenCloneFactory(admin);
        token = TokenCloneable(tokenFactory.createToken("Security Token", "SEC", 18, admin));
        identityFactory = new IdentityCloneFactory(admin);

        identityRegistry = new IdentityRegistry(admin);
        trustedIssuersRegistry = new TrustedIssuersRegistry(admin);
        claimTopicsRegistry = new ClaimTopicsRegistry(admin);

        token.setIdentityRegistry(address(identityRegistry));
        token.setTrustedIssuersRegistry(address(trustedIssuersRegistry));
        token.setClaimTopicsRegistry(address(claimTopicsRegistry));

        uint256[] memory issuerTopics = new uint256[](2);
        issuerTopics[0] = KYC_TOPIC;
        issuerTopics[1] = AML_TOPIC;
        trustedIssuersRegistry.addTrustedIssuer(issuer, issuerTopics);

        // Solo KYC es obligatorio para `isVerified`; AML existe en las identidades pero no se exige.
        claimTopicsRegistry.addClaimTopic(KYC_TOPIC);

        for (uint256 i = 0; i < 3; i++) {
            address actor = makeAddr(string(abi.encodePacked("idActor", i)));
            IdentityCloneable identity = IdentityCloneable(identityFactory.createIdentity(admin));
            identityRegistry.registerIdentity(actor, address(identity));
            _addClaim(identity, KYC_TOPIC, abi.encode("KYC", address(identity)));
            _addClaim(identity, AML_TOPIC, abi.encode("AML", address(identity)));
            actors.push(actor);
            identities.push(identity);
        }

        claimTopicsPool = [KYC_TOPIC, AML_TOPIC];

        ghosts = new IdentityGhosts();
        address[] memory nonIssuerCallers = new address[](3);
        nonIssuerCallers[0] = admin;
        nonIssuerCallers[1] = actors[0];
        nonIssuerCallers[2] = actors[1];

        handler = new IdentityHandler(
            IdentityHandler.Config({
                identities: identities,
                identityOwner: admin,
                issuer: issuer,
                issuerPk: ISSUER_PK,
                topics: claimTopicsPool,
                ghosts: ghosts
            }),
            nonIssuerCallers
        );

        targetContract(address(handler));
    }

    function _addClaim(IdentityCloneable identity, uint256 topic, bytes memory data) internal {
        bytes memory signature = SigUtils.signClaim(ISSUER_PK, address(identity), admin, topic, 1, data, 0, 0);
        identity.addClaim(topic, 1, issuer, signature, data, "", 0);
    }

    // ============ Invariantes ============

    /// @notice El `claimNonce` solo crece (nunca decrece) para ningun par (identidad, topic).
    function invariant_claimNonce_no_decrece() public view {
        for (uint256 i = 0; i < identities.length; i++) {
            for (uint256 t = 0; t < claimTopicsPool.length; t++) {
                uint256 nonce = identities[i].claimNonce(claimTopicsPool[t], issuer);
                assertGe(nonce, ghosts.maxNonce(address(identities[i]), claimTopicsPool[t]), "claimNonce ha decrecido");
            }
        }
    }

    /// @notice Ninguna cuenta distinta del issuer ha podido revocar un claim.
    function invariant_revokeClaim_solo_issuer() public view {
        assertFalse(ghosts.revokeUnauthorizedViolated(), "revokeClaim acepto a una cuenta distinta del issuer");
    }

    /// @notice `hasValidClaim(topic, issuer)` == existe && no revocado && (sin caducidad o no vencido).
    function invariant_hasValidClaim_semantica() public view {
        for (uint256 i = 0; i < identities.length; i++) {
            IdentityCloneable identity = identities[i];
            for (uint256 t = 0; t < claimTopicsPool.length; t++) {
                uint256 topic = claimTopicsPool[t];
                (,, address claimIssuer,,,, uint256 expiresAt, bool revoked) = identity.getClaim(topic, issuer);
                bool expected = claimIssuer != address(0) && !revoked && (expiresAt == 0 || block.timestamp < expiresAt);
                assertEq(
                    identity.hasValidClaim(topic, issuer),
                    expected,
                    "hasValidClaim no coincide con (existe && !revocado && no vencido)"
                );
            }
        }
    }

    /// @notice Un claim revocado o vencido nunca verifica: `isVerified` equivale a que todos los
    /// topics requeridos esten cubiertos por un claim vigente y no revocado de un issuer autorizado.
    function invariant_isVerified_equivalente_a_claim_valido() public view {
        for (uint256 i = 0; i < actors.length; i++) {
            assertEq(
                token.isVerified(actors[i]),
                _allTopicsSatisfied(actors[i]),
                "isVerified no equivale a claim vigente de issuer autorizado"
            );
        }
    }

    /// @notice Comprobacion del harness (test normal, no invariante): las acciones del handler
    /// alcanzan caminos de exito reales. Se hace como `test_` y no como `invariant_` porque una
    /// secuencia valida puede tener cero exitos sin violar ninguna propiedad.
    function test_handler_operativo() public {
        handler.addClaim(0, 0, 0);
        assertGt(ghosts.successCount("addClaim"), 0, "addClaim no tuvo exito");

        handler.revokeClaim(0, 0);
        assertGt(ghosts.successCount("revokeClaim"), 0, "revokeClaim no tuvo exito");

        handler.removeClaim(0, 1);
        assertGt(ghosts.successCount("removeClaim"), 0, "removeClaim no tuvo exito");
    }

    // ============ Helper ============

    function _allTopicsSatisfied(address account) internal view returns (bool) {
        if (!identityRegistry.isRegistered(account)) {
            return false;
        }
        address identity = identityRegistry.getIdentity(account);
        if (identity == address(0)) {
            return false;
        }
        uint256[] memory required = claimTopicsRegistry.getClaimTopics();
        if (required.length == 0) {
            return false;
        }
        address[] memory trusted = trustedIssuersRegistry.getTrustedIssuers();

        for (uint256 i = 0; i < required.length; i++) {
            bool topicSatisfied = false;
            for (uint256 j = 0; j < trusted.length; j++) {
                if (!trustedIssuersRegistry.hasClaimTopic(trusted[j], required[i])) {
                    continue;
                }
                (bool success, bytes memory data) = identity.staticcall(
                    abi.encodeWithSignature("hasValidClaim(uint256,address)", required[i], trusted[j])
                );
                if (success && data.length >= 32 && abi.decode(data, (bool))) {
                    topicSatisfied = true;
                    break;
                }
            }
            if (!topicSatisfied) {
                return false;
            }
        }
        return true;
    }
}
