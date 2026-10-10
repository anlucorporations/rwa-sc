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
import {IClaimTopicsRegistry} from "../../src/IClaimTopicsRegistry.sol";
import {MaxBalanceCompliance} from "../../src/compliance/MaxBalanceCompliance.sol";
import {MaxHoldersCompliance} from "../../src/compliance/MaxHoldersCompliance.sol";
import {SigUtils} from "../helpers/SigUtils.sol";
import {TokenGhosts, TokenHandler} from "./handlers/TokenHandler.sol";

/**
 * @title TokenInvariantsTest
 * @notice Invariantes con estado de `TokenCloneable` (RF-009 / Fase 4).
 *
 * Cubre contabilidad (suministro == suma de saldos, `maxSupply`), seguridad de las operaciones
 * privilegiadas (`maxBurnPerTx`, whitelist y `maxForcedPerTx` de `forcedTransfer`), cuentas
 * congeladas / token pausado, el guard `nonReentrant` (no se queda "pegado") y la equivalencia
 * `isVerified` <-> existe claim vigente y no revocado de un issuer autorizado por topic.
 *
 * Los "call properties" se comprueban con los flags de `TokenGhosts` (ver `TokenHandler`).
 */
contract TokenInvariantsTest is Test {
    TokenCloneable internal token;
    TokenCloneFactory internal tokenFactory;
    IdentityCloneFactory internal identityFactory;
    IdentityRegistry internal identityRegistry;
    TrustedIssuersRegistry internal trustedIssuersRegistry;
    ClaimTopicsRegistry internal claimTopicsRegistry;
    MaxBalanceCompliance internal maxBalanceCompliance;
    MaxHoldersCompliance internal maxHoldersCompliance;

    TokenGhosts internal ghosts;
    TokenHandler internal handler;

    address internal admin = address(this);
    address internal issuer;
    uint256 internal constant ISSUER_PK = 0xB0B;
    uint256 internal constant KYC_TOPIC = 1;
    uint256 internal constant AML_TOPIC = 2;
    uint256 internal constant MAX_BALANCE = 1_000e18;
    uint256 internal constant MAX_HOLDERS = 5;

    address[] internal actors;
    IdentityCloneable[] internal identities;

    function setUp() public {
        issuer = vm.addr(ISSUER_PK);

        tokenFactory = new TokenCloneFactory(admin);
        identityFactory = new IdentityCloneFactory(admin);
        token = TokenCloneable(tokenFactory.createToken("Security Token", "SEC", 18, admin));

        identityRegistry = new IdentityRegistry(admin);
        trustedIssuersRegistry = new TrustedIssuersRegistry(admin);
        claimTopicsRegistry = new ClaimTopicsRegistry(admin);

        maxBalanceCompliance = new MaxBalanceCompliance(admin, MAX_BALANCE);
        maxHoldersCompliance = new MaxHoldersCompliance(admin, MAX_HOLDERS);

        token.setIdentityRegistry(address(identityRegistry));
        token.setTrustedIssuersRegistry(address(trustedIssuersRegistry));
        token.setClaimTopicsRegistry(address(claimTopicsRegistry));

        maxBalanceCompliance.setTokenContract(address(token));
        maxHoldersCompliance.setTokenContract(address(token));
        token.addComplianceModule(address(maxBalanceCompliance));
        token.addComplianceModule(address(maxHoldersCompliance));

        uint256[] memory issuerTopics = new uint256[](2);
        issuerTopics[0] = KYC_TOPIC;
        issuerTopics[1] = AML_TOPIC;
        trustedIssuersRegistry.addTrustedIssuer(issuer, issuerTopics);
        claimTopicsRegistry.addClaimTopic(KYC_TOPIC);
        claimTopicsRegistry.addClaimTopic(AML_TOPIC);

        // Actores e identidades (owner = este contrato de test, como en las suites unitarias).
        for (uint256 i = 0; i < 5; i++) {
            address actor = makeAddr(string(abi.encodePacked("invActor", i)));
            IdentityCloneable identity = IdentityCloneable(identityFactory.createIdentity(admin));
            identityRegistry.registerIdentity(actor, address(identity));
            _addClaims(identity);
            actors.push(actor);
            identities.push(identity);
            // Saldo inicial para que las transferencias sean alcanzables.
            token.mint(actor, 100e18);
        }

        // RF-004: topes y whitelist configurables; se arranca con un escenario permisivo para
        // que el handler pueda explorar tanto el exito como el rechazo.
        token.setMaxBurnPerTx(500e18);
        token.setMaxForcedPerTx(500e18);
        for (uint256 i = 0; i < actors.length; i++) {
            token.setAuthorizedDestination(actors[i], true);
        }

        // El handler administra la politica de claims; las identidades siguen siendo de admin.
        trustedIssuersRegistry.transferOwnership(address(this));
        claimTopicsRegistry.transferOwnership(address(this));

        ghosts = new TokenGhosts();
        address[] memory modules = new address[](2);
        modules[0] = address(maxBalanceCompliance);
        modules[1] = address(maxHoldersCompliance);
        handler = new TokenHandler(
            TokenHandler.Config({
                token: token,
                issuers: trustedIssuersRegistry,
                topics: claimTopicsRegistry,
                ghosts: ghosts,
                identityOwner: admin,
                issuer: issuer,
                issuerPk: ISSUER_PK,
                kycTopic: KYC_TOPIC,
                amlTopic: AML_TOPIC
            }),
            actors,
            identities,
            modules
        );

        // El handler necesita roles del token y la propiedad de los registries mutables.
        token.grantRole(token.DEFAULT_ADMIN_ROLE(), address(handler));
        token.grantRole(token.AGENT_ROLE(), address(handler));
        token.grantRole(token.COMPLIANCE_ROLE(), address(handler));
        trustedIssuersRegistry.transferOwnership(address(handler));
        claimTopicsRegistry.transferOwnership(address(handler));

        // `transferFrom` del handler: allowance permanente de cada actor.
        for (uint256 i = 0; i < actors.length; i++) {
            vm.prank(actors[i]);
            token.approve(address(handler), type(uint256).max);
        }

        targetContract(address(handler));
    }

    function _addClaims(IdentityCloneable identity) internal {
        _addClaim(identity, KYC_TOPIC, abi.encode("KYC", address(identity)));
        _addClaim(identity, AML_TOPIC, abi.encode("AML", address(identity)));
    }

    function _addClaim(IdentityCloneable identity, uint256 topic, bytes memory data) internal {
        // D-038: `expiresAt == 0` = sin caducidad.
        bytes memory signature = SigUtils.signClaim(ISSUER_PK, address(identity), admin, topic, 1, data, 0, 0);
        identity.addClaim(topic, 1, issuer, signature, data, "", 0);
    }

    // ============ Invariantes ============

    /// @notice `totalSupply()` == suma de los saldos de los actores manejados.
    function invariant_totalSupply_igual_suma_de_saldos() public view {
        uint256 sum = 0;
        for (uint256 i = 0; i < actors.length; i++) {
            sum += token.balanceOf(actors[i]);
        }
        assertEq(token.totalSupply(), sum, "totalSupply != suma de saldos de los actores");
    }

    /// @notice `maxSupply == 0 || totalSupply() <= maxSupply` (D-022).
    function invariant_maxSupply_respetado() public view {
        uint256 cap = token.maxSupply();
        assertTrue(cap == 0 || token.totalSupply() <= cap, "totalSupply por encima de maxSupply");
    }

    /// @notice `totalSupply()` nunca decrece salvo por `burn`.
    function invariant_totalSupply_solo_baja_por_burn() public view {
        assertFalse(ghosts.supplyDecreasedWithoutBurn(), "totalSupply decrecio en una operacion distinta de burn");
    }

    /// @notice `burn` nunca supera `maxBurnPerTx` ni ocurre con `maxBurnPerTx == 0` (CU-06 A6.5).
    function invariant_burn_no_supera_limite() public view {
        assertFalse(ghosts.burnLimitViolated(), "burn supero maxBurnPerTx o quemo con tope 0");
    }

    /// @notice Todo `forcedTransfer` con exito va a un destino autorizado y respeta `maxForcedPerTx`.
    function invariant_forcedTransfer_destino_autorizado() public view {
        assertFalse(ghosts.forcedDestViolated(), "forcedTransfer a destino no autorizado");
        assertFalse(ghosts.forcedLimitViolated(), "forcedTransfer supero maxForcedPerTx");
    }

    /// @notice Ninguna transferencia (`transfer`/`transferFrom`) con exito usa cuentas congeladas
    /// ni un token pausado.
    function invariant_transferencia_sin_congelados_ni_pausa() public view {
        assertFalse(ghosts.frozenTransferViolated(), "transferencia con cuenta congelada");
        assertFalse(ghosts.pausedTransferViolated(), "transferencia con el token pausado");
    }

    /// @notice El guard `nonReentrant` no se queda "pegado": tras cualquier secuencia, una llamada
    /// guardada sigue siendo alcanzable (no revierte con `ReentrancyGuardReentrantCall`).
    function invariant_guard_nonReentrant_no_pegado() public {
        address actor = actors[0];
        (bool ok, bytes memory data) = address(token).call(abi.encodeCall(TokenCloneable.mint, (actor, 0)));
        if (!ok && data.length >= 4) {
            bytes4 selector;
            assembly {
                selector := mload(add(data, 0x20))
            }
            assertTrue(selector != bytes4(keccak256("ReentrancyGuardReentrantCall()")), "guard nonReentrant pegado");
        }
    }

    /// @notice `isVerified(a) == true` si y solo si todos los topics requeridos estan cubiertos por
    /// un claim vigente y no revocado de un issuer autorizado para ese topic.
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
    /// alcanzan caminos de exito reales, de modo que los invariantes anteriores no pasan de forma
    /// trivial. Se hace como `test_` y no como `invariant_` porque una secuencia valida puede
    /// tener cero exitos (p. ej. todas las acciones acotadas revierten) sin violar nada.
    function test_handler_operativo() public {
        handler.mint(0, 1e18);
        assertGt(ghosts.successCount("mint"), 0, "mint no tuvo exito");

        handler.transfer(0, 1, 1e18);
        assertGt(ghosts.successCount("transfer"), 0, "transfer no tuvo exito");

        handler.forcedTransfer(0, 1, 1e18);
        assertGt(ghosts.successCount("forcedTransfer"), 0, "forcedTransfer no tuvo exito");

        handler.burn(0, 1e18);
        assertGt(ghosts.successCount("burn"), 0, "burn no tuvo exito");
    }

    // ============ Helper ============

    function _allTopicsSatisfied(address account) internal view returns (bool) {
        IdentityRegistry registry = token.identityRegistry();
        if (address(registry) == address(0) || !registry.isRegistered(account)) {
            return false;
        }
        address identity = registry.getIdentity(account);
        if (identity == address(0)) {
            return false;
        }

        IClaimTopicsRegistry topicsRegistry = token.claimTopicsRegistry();
        if (address(topicsRegistry) == address(0)) {
            return false;
        }
        uint256[] memory required = topicsRegistry.getClaimTopics();
        if (required.length == 0) {
            return false;
        }

        TrustedIssuersRegistry issuersRegistry = token.trustedIssuersRegistry();
        if (address(issuersRegistry) == address(0)) {
            return false;
        }
        address[] memory trusted = issuersRegistry.getTrustedIssuers();

        for (uint256 i = 0; i < required.length; i++) {
            bool topicSatisfied = false;
            for (uint256 j = 0; j < trusted.length; j++) {
                if (!issuersRegistry.hasClaimTopic(trusted[j], required[i])) {
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
