// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IdentityCloneFactory} from "../../src/IdentityCloneFactory.sol";
import {IdentityRegistry} from "../../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../../src/TrustedIssuersRegistry.sol";
import {ClaimTopicsRegistryCloneable} from "../../src/ClaimTopicsRegistryCloneable.sol";
import {ClaimTopicsRegistryCloneFactory} from "../../src/ClaimTopicsRegistryCloneFactory.sol";
import {RegistryGhosts, RegistryHandler} from "./handlers/RegistryHandler.sol";

/**
 * @title RegistryInvariantsTest
 * @notice Invariantes con estado de los registries (RF-009 / Fase 4).
 *
 * Comprueba que el array y el mapping de `IdentityRegistry` y `TrustedIssuersRegistry`, y el
 * array de `ClaimTopicsRegistryCloneable`, nunca se desincronizan: todo elemento del array existe
 * en el mapping y viceversa, el contador coincide con el tamano del array, no hay duplicados ni
 * huecos, y el estado es consistente tras altas/bajas en cualquier orden.
 *
 * El `handler` mantiene un modelo fantasma (`RegistryGhosts`) de la pertenencia esperada; los
 * invariantes comparan el contrato real con ese modelo.
 */
contract RegistryInvariantsTest is Test {
    IdentityCloneFactory internal identityFactory;
    ClaimTopicsRegistryCloneFactory internal topicsFactory;

    IdentityRegistry internal identityRegistry;
    TrustedIssuersRegistry internal issuersRegistry;
    ClaimTopicsRegistryCloneable internal topicsRegistry;

    RegistryGhosts internal ghosts;
    RegistryHandler internal handler;

    address internal admin = address(this);
    address[] internal wallets;
    address[] internal identities;
    address[] internal issuers;
    uint256[] internal topicPool;

    function setUp() public {
        identityFactory = new IdentityCloneFactory(admin);
        topicsFactory = new ClaimTopicsRegistryCloneFactory(admin);

        identityRegistry = new IdentityRegistry(admin);
        issuersRegistry = new TrustedIssuersRegistry(admin);
        topicsRegistry = ClaimTopicsRegistryCloneable(topicsFactory.createRegistry(admin));

        for (uint256 i = 0; i < 5; i++) {
            wallets.push(makeAddr(string(abi.encodePacked("regWallet", i))));
        }
        for (uint256 i = 0; i < 6; i++) {
            identities.push(identityFactory.createIdentity(admin));
        }
        for (uint256 i = 0; i < 4; i++) {
            issuers.push(makeAddr(string(abi.encodePacked("regIssuer", i))));
        }
        topicPool = [uint256(1), 2, 3];

        ghosts = new RegistryGhosts();
        handler = new RegistryHandler(
            RegistryHandler.Config({
                identityRegistry: identityRegistry,
                issuersRegistry: issuersRegistry,
                topicsRegistry: topicsRegistry,
                ghosts: ghosts
            }),
            wallets,
            identities,
            issuers
        );

        identityRegistry.transferOwnership(address(handler));
        issuersRegistry.transferOwnership(address(handler));
        topicsRegistry.transferOwnership(address(handler));

        targetContract(address(handler));
    }

    // ============ Invariantes ============

    /// @notice `IdentityRegistry`: array <-> mapping sincronizados, contador correcto, sin
    /// duplicados ni huecos, y coherente con el modelo fantasma.
    function invariant_identityRegistry_sincronizado() public view {
        uint256 count = identityRegistry.getRegisteredCount();
        address[] memory registered = _registeredArray(count);

        assertEq(registered.length, count, "contador != tamano del array (IdentityRegistry)");
        assertFalse(_hasDuplicate(registered), "duplicados en registeredAddresses");

        for (uint256 i = 0; i < count; i++) {
            assertTrue(identityRegistry.isRegistered(registered[i]), "elemento del array no registrado en el mapping");
            assertTrue(
                identityRegistry.getIdentity(registered[i]) != address(0), "elemento del array sin identidad asociada"
            );
        }

        uint256 expected = 0;
        for (uint256 i = 0; i < wallets.length; i++) {
            if (ghosts.expectedRegistered(wallets[i])) {
                expected++;
            }
            assertEq(
                identityRegistry.isRegistered(wallets[i]),
                ghosts.expectedRegistered(wallets[i]),
                "mapping difiere del modelo fantasma"
            );
        }
        assertEq(count, expected, "array y modelo fantasma discrepan en cardinalidad");
    }

    /// @notice `TrustedIssuersRegistry`: array <-> mapping sincronizados, contador correcto, sin
    /// duplicados, todo emisor del array tiene topics no vacios.
    function invariant_trustedIssuers_sincronizado() public view {
        address[] memory trusted = issuersRegistry.getTrustedIssuers();

        assertEq(
            trusted.length,
            issuersRegistry.getTrustedIssuersCount(),
            "contador != tamano del array (TrustedIssuersRegistry)"
        );
        assertFalse(_hasDuplicate(trusted), "duplicados en trustedIssuersList");

        for (uint256 i = 0; i < trusted.length; i++) {
            assertTrue(issuersRegistry.isTrustedIssuer(trusted[i]), "elemento del array no esta en el mapping");
            assertTrue(issuersRegistry.getIssuerClaimTopics(trusted[i]).length > 0, "emisor confiable sin claim topics");
        }

        uint256 expected = 0;
        for (uint256 i = 0; i < issuers.length; i++) {
            if (ghosts.expectedTrusted(issuers[i])) {
                expected++;
            }
            assertEq(
                issuersRegistry.isTrustedIssuer(issuers[i]),
                ghosts.expectedTrusted(issuers[i]),
                "mapping de emisores difiere del modelo fantasma"
            );
        }
        assertEq(trusted.length, expected, "array de emisores y modelo fantasma discrepan");
    }

    /// @notice `ClaimTopicsRegistryCloneable`: contador correcto, sin duplicados, sin topic 0 y
    /// `claimTopicExists` coherente con el modelo fantasma.
    function invariant_claimTopics_sincronizado() public view {
        uint256[] memory topics = topicsRegistry.getClaimTopics();

        assertEq(
            topics.length, topicsRegistry.getClaimTopicsCount(), "contador != tamano del array (ClaimTopicsRegistry)"
        );
        assertFalse(_hasDuplicateUint(topics), "duplicados en claimTopics");

        for (uint256 i = 0; i < topics.length; i++) {
            assertTrue(topics[i] != 0, "topic 0 en el array (reservado)");
            assertTrue(topicsRegistry.claimTopicExists(topics[i]), "claimTopicExists falso para un elemento del array");
        }

        uint256 expected = 0;
        for (uint256 i = 0; i < topicPool.length; i++) {
            if (ghosts.expectedTopic(topicPool[i])) {
                expected++;
            }
            assertEq(
                topicsRegistry.claimTopicExists(topicPool[i]),
                ghosts.expectedTopic(topicPool[i]),
                "claimTopicExists difiere del modelo fantasma"
            );
        }
        assertEq(topics.length, expected, "array de topics y modelo fantasma discrepan");
    }

    /// @notice Comprobacion del harness (test normal, no invariante): las acciones del handler
    /// alcanzan caminos de exito reales. Se hace como `test_` y no como `invariant_` porque una
    /// secuencia valida puede tener cero exitos sin violar ninguna propiedad.
    function test_handler_operativo() public {
        handler.registerIdentity(0, 0);
        assertGt(ghosts.successCount("registerIdentity"), 0, "registerIdentity no tuvo exito");

        handler.addTrustedIssuer(0, 1);
        assertGt(ghosts.successCount("addTrustedIssuer"), 0, "addTrustedIssuer no tuvo exito");

        handler.addClaimTopic(1);
        assertGt(ghosts.successCount("addClaimTopic"), 0, "addClaimTopic no tuvo exito");

        handler.removeIdentity(0);
        assertGt(ghosts.successCount("removeIdentity"), 0, "removeIdentity no tuvo exito");
    }

    // ============ Helpers ============

    function _registeredArray(uint256 count) internal view returns (address[] memory arr) {
        arr = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            arr[i] = identityRegistry.getRegisteredAddress(i);
        }
    }

    function _hasDuplicate(address[] memory arr) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; i++) {
            for (uint256 j = i + 1; j < arr.length; j++) {
                if (arr[i] == arr[j]) {
                    return true;
                }
            }
        }
        return false;
    }

    function _hasDuplicateUint(uint256[] memory arr) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; i++) {
            for (uint256 j = i + 1; j < arr.length; j++) {
                if (arr[i] == arr[j]) {
                    return true;
                }
            }
        }
        return false;
    }
}
