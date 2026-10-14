// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";
import {TokenCloneFactory} from "../src/TokenCloneFactory.sol";
import {IdentityCloneFactory} from "../src/IdentityCloneFactory.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";
import {ClaimTopicsRegistry} from "../src/ClaimTopicsRegistry.sol";
import {ClaimTopicsRegistryCloneable} from "../src/ClaimTopicsRegistryCloneable.sol";
import {ClaimTopicsRegistryCloneFactory} from "../src/ClaimTopicsRegistryCloneFactory.sol";
import {ComplianceAggregator} from "../src/compliance/ComplianceAggregator.sol";
import {MaxBalanceCompliance} from "../src/compliance/MaxBalanceCompliance.sol";

/**
 * @title H20_EscalabilidadTest
 * @notice Suite de H-20 (auditoria V1 / plan M-11): indices O(1) y vistas paginadas.
 *
 * Los arrays de enumeracion (`registeredAddresses`, `trustedIssuersList`, `claimTopics`,
 * `complianceModules`) se conservan para no romper ABI; H-20 anade a su lado mappings de indice
 * para que la pertenencia y el borrado sean O(1) (antes O(n)), y vistas paginadas para no
 * materializar el array completo. Esta suite verifica ambas cosas, incluido que el swap-and-pop
 * sigue dejando el array sin huecos.
 */
contract H20EscalabilidadTest is Test {
    address internal admin = address(this);

    TokenCloneable internal token;
    IdentityCloneFactory internal identityFactory;
    ClaimTopicsRegistryCloneFactory internal topicsFactory;

    IdentityRegistry internal identityRegistry;
    TrustedIssuersRegistry internal trustedIssuersRegistry;
    ClaimTopicsRegistry internal claimTopicsRegistry;

    function setUp() public {
        TokenCloneFactory tokenFactory = new TokenCloneFactory(admin);
        identityFactory = new IdentityCloneFactory(admin);
        topicsFactory = new ClaimTopicsRegistryCloneFactory(admin);

        token = TokenCloneable(tokenFactory.createToken("Escalabilidad", "ESC", 18, admin));

        identityRegistry = new IdentityRegistry(admin);
        trustedIssuersRegistry = new TrustedIssuersRegistry(admin);
        claimTopicsRegistry = new ClaimTopicsRegistry(admin);
    }

    // ================= IdentityRegistry =================

    function test_H20_identityRegistry_paginado_y_borrado_O1() public {
        address[5] memory wallets;
        for (uint256 i = 0; i < 5; i++) {
            wallets[i] = makeAddr(string(abi.encodePacked("wallet", i)));
            identityRegistry.registerIdentity(wallets[i], identityFactory.createIdentity(wallets[i]));
        }
        assertEq(identityRegistry.getRegisteredCount(), 5);

        // Paginado: primera pagina, ultima pagina parcial y fuera de rango.
        address[] memory page = identityRegistry.getRegisteredAddressesPaginated(0, 2);
        assertEq(page.length, 2);
        assertEq(page[0], wallets[0]);
        assertEq(page[1], wallets[1]);

        page = identityRegistry.getRegisteredAddressesPaginated(4, 10);
        assertEq(page.length, 1);
        assertEq(page[0], wallets[4]);

        assertEq(identityRegistry.getRegisteredAddressesPaginated(5, 2).length, 0, "offset fuera de rango");
        assertEq(identityRegistry.getRegisteredAddressesPaginated(0, 0).length, 0, "limit 0");

        // Borrado del del medio en O(1): swap-and-pop sin huecos.
        identityRegistry.removeIdentity(wallets[1]);
        assertEq(identityRegistry.getRegisteredCount(), 4);
        assertEq(identityRegistry.getRegisteredAddress(1), wallets[4], "el ultimo ocupa el hueco");
        assertFalse(identityRegistry.isRegistered(wallets[1]));
        assertEq(identityRegistry.getRegisteredAddress(2), wallets[2]);
        assertEq(identityRegistry.getRegisteredAddress(3), wallets[3]);

        // Se puede volver a registrar sin duplicar.
        identityRegistry.registerIdentity(wallets[1], identityFactory.createIdentity(wallets[1]));
        assertEq(identityRegistry.getRegisteredCount(), 5);
    }

    // ================= TrustedIssuersRegistry =================

    function test_H20_trustedIssuers_paginado_y_hasClaimTopic_O1() public {
        address issuerA = makeAddr("issuerA");
        address issuerB = makeAddr("issuerB");
        address issuerC = makeAddr("issuerC");

        uint256[] memory t1 = new uint256[](1);
        t1[0] = 1;
        uint256[] memory t2 = new uint256[](2);
        t2[0] = 2;
        t2[1] = 3;
        uint256[] memory t3 = new uint256[](1);
        t3[0] = 4;

        trustedIssuersRegistry.addTrustedIssuer(issuerA, t1);
        trustedIssuersRegistry.addTrustedIssuer(issuerB, t2);
        trustedIssuersRegistry.addTrustedIssuer(issuerC, t3);

        assertTrue(trustedIssuersRegistry.hasClaimTopic(issuerB, 2));
        assertTrue(trustedIssuersRegistry.hasClaimTopic(issuerB, 3));
        assertFalse(trustedIssuersRegistry.hasClaimTopic(issuerB, 1));

        // update sincroniza la pertenencia O(1): el topic viejo deja de existir.
        uint256[] memory t2b = new uint256[](1);
        t2b[0] = 5;
        trustedIssuersRegistry.updateIssuerClaimTopics(issuerB, t2b);
        assertFalse(trustedIssuersRegistry.hasClaimTopic(issuerB, 2), "topic retirado");
        assertTrue(trustedIssuersRegistry.hasClaimTopic(issuerB, 5), "topic nuevo");

        address[] memory page = trustedIssuersRegistry.getTrustedIssuersPaginated(0, 2);
        assertEq(page.length, 2);
        assertEq(page[0], issuerA);
        assertEq(page[1], issuerB);

        // remove en O(1) (swap-and-pop) + limpieza de pertenencia.
        trustedIssuersRegistry.removeTrustedIssuer(issuerA);
        assertEq(trustedIssuersRegistry.getTrustedIssuersCount(), 2);
        assertEq(trustedIssuersRegistry.getTrustedIssuers()[0], issuerC, "el ultimo ocupa el hueco");
        assertFalse(trustedIssuersRegistry.hasClaimTopic(issuerA, 1));
        assertFalse(trustedIssuersRegistry.isTrustedIssuer(issuerA));
        assertEq(trustedIssuersRegistry.getTrustedIssuersPaginated(2, 5).length, 0);
    }

    // ================= ClaimTopicsRegistry =================

    function test_H20_claimTopics_paginado_y_borrado_O1() public {
        for (uint256 i = 1; i <= 4; i++) {
            claimTopicsRegistry.addClaimTopic(i);
        }
        assertTrue(claimTopicsRegistry.claimTopicExists(3));

        uint256[] memory page = claimTopicsRegistry.getClaimTopicsPaginated(1, 2);
        assertEq(page.length, 2);
        assertEq(page[0], 2);
        assertEq(page[1], 3);

        assertEq(claimTopicsRegistry.getClaimTopicsPaginated(4, 2).length, 0);
        assertEq(claimTopicsRegistry.getClaimTopicsPaginated(0, 0).length, 0);

        // remove O(1): swap-and-pop y bandera de existencia sincronizada.
        claimTopicsRegistry.removeClaimTopic(2);
        assertFalse(claimTopicsRegistry.claimTopicExists(2));
        assertEq(claimTopicsRegistry.getClaimTopicsCount(), 3);
        assertEq(claimTopicsRegistry.getClaimTopics()[1], 4, "el ultimo ocupa el hueco");
    }

    function test_H20_claimTopicsCloneable_paginado() public {
        uint256[] memory initial = new uint256[](2);
        initial[0] = 7;
        initial[1] = 8;
        ClaimTopicsRegistryCloneable registry =
            ClaimTopicsRegistryCloneable(topicsFactory.createRegistryWithTopics(admin, initial));

        assertTrue(registry.claimTopicExists(7));
        uint256[] memory page = registry.getClaimTopicsPaginated(0, 1);
        assertEq(page.length, 1);
        assertEq(page[0], 7);

        registry.removeClaimTopic(7);
        assertFalse(registry.claimTopicExists(7));
        assertEq(registry.getClaimTopicsCount(), 1);
        assertEq(registry.getClaimTopicsPaginated(0, 5).length, 1);
    }

    // ================= TokenCloneable =================

    function _boundModule() internal returns (MaxBalanceCompliance module) {
        module = new MaxBalanceCompliance(admin, 1000 * 10 ** 18);
        module.setTokenContract(address(token));
    }

    function test_H20_token_modulos_removeByAddress_y_paginado() public {
        MaxBalanceCompliance m1 = _boundModule();
        MaxBalanceCompliance m2 = _boundModule();
        MaxBalanceCompliance m3 = _boundModule();

        token.addComplianceModule(address(m1));
        token.addComplianceModule(address(m2));
        token.addComplianceModule(address(m3));
        assertEq(token.getComplianceModules().length, 3);

        address[] memory page = token.getComplianceModulesPaginated(1, 2);
        assertEq(page.length, 2);
        assertEq(page[0], address(m2));
        assertEq(page[1], address(m3));
        assertEq(token.getComplianceModulesPaginated(3, 2).length, 0);
        assertEq(token.getComplianceModulesPaginated(0, 0).length, 0);

        // Alta duplicada rechazada por el indice O(1).
        vm.expectRevert("Module already added");
        token.addComplianceModule(address(m2));

        // Borrado por direccion en O(1): m3 ocupa el hueco de m1.
        token.removeComplianceModuleByAddress(address(m1));
        address[] memory remaining = token.getComplianceModules();
        assertEq(remaining.length, 2);
        assertEq(remaining[0], address(m3), "el ultimo ocupa el hueco");
        assertEq(remaining[1], address(m2));

        // El indice queda consistente: borrar por indice sigue funcionando.
        token.removeComplianceModule(1);
        assertEq(token.getComplianceModules().length, 1);
        assertEq(token.getComplianceModules()[0], address(m3));

        // Borrar un modulo ausente revierte de forma explicita.
        vm.expectRevert("Module not added");
        token.removeComplianceModuleByAddress(address(m1));
    }

    // ================= ComplianceAggregator =================

    function test_H20_aggregator_paginado() public {
        ComplianceAggregator aggregator = new ComplianceAggregator(admin);
        MaxBalanceCompliance mb1 = _boundModule();
        MaxBalanceCompliance mb2 = _boundModule();

        token.addComplianceModule(address(aggregator));
        token.addModuleThroughAggregator(address(aggregator), address(mb1));
        token.addModuleThroughAggregator(address(aggregator), address(mb2));
        assertEq(aggregator.getModuleCount(address(token)), 2);

        address[] memory page = aggregator.getModulesPaginated(address(token), 0, 1);
        assertEq(page.length, 1);
        assertEq(page[0], address(mb1));

        page = aggregator.getModulesPaginated(address(token), 1, 5);
        assertEq(page.length, 1);
        assertEq(page[0], address(mb2));

        assertEq(aggregator.getModulesPaginated(address(token), 9, 5).length, 0);
        assertEq(aggregator.getModulesPaginated(address(token), 0, 0).length, 0);

        address[] memory tokenPage = aggregator.getTokensPaginated(0, 10);
        assertEq(tokenPage.length, 1);
        assertEq(tokenPage[0], address(token));
        assertEq(aggregator.getTokensPaginated(1, 10).length, 0);

        // La retirada por el aggregator (O(1) ya existente) mantiene la consistencia.
        token.removeModuleThroughAggregator(address(aggregator), address(mb1));
        assertEq(aggregator.getModuleCount(address(token)), 1);
        assertEq(aggregator.getModulesPaginated(address(token), 0, 5)[0], address(mb2));
    }
}
