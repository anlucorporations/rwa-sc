// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";
import {IdentityCloneable} from "../src/IdentityCloneable.sol";
import {TokenCloneFactory} from "../src/TokenCloneFactory.sol";
import {IdentityCloneFactory} from "../src/IdentityCloneFactory.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";
import {ClaimTopicsRegistry} from "../src/ClaimTopicsRegistry.sol";
import {SigUtils} from "./helpers/SigUtils.sol";

/**
 * @title RF011_FailClosedTest
 * @notice Pruebas de RF-011 (Ciclo 6) segun CU-15: `isVerified` debe ser **fail-closed**. Un token sin
 * `claimTopicsRegistry` configurado, o con el conjunto de topics requeridos vacio, no verifica a nadie
 * (antes devolvia `true` para cualquier wallet registrada: fail-open, H-05 de la auditoria V1).
 */
contract RF011_FailClosedTest is Test {
    uint256 internal constant ISSUER_PK = 0xA11CE;
    uint256 internal constant KYC_TOPIC = 1;
    /// @dev D-038: `expiresAt == 0` = sin caducidad.
    uint256 internal constant EXPIRES_AT = 0;

    address internal admin = address(this);
    address internal issuer;
    address internal user1;
    address internal user2;

    TokenCloneFactory internal tokenFactory;
    IdentityCloneFactory internal identityFactory;
    IdentityRegistry internal identityRegistry;
    TrustedIssuersRegistry internal trustedIssuersRegistry;
    ClaimTopicsRegistry internal claimTopicsRegistry;

    TokenCloneable internal token;

    function setUp() public {
        issuer = vm.addr(ISSUER_PK);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        tokenFactory = new TokenCloneFactory(admin);
        identityFactory = new IdentityCloneFactory(admin);

        identityRegistry = new IdentityRegistry(admin);
        trustedIssuersRegistry = new TrustedIssuersRegistry(admin);
        claimTopicsRegistry = new ClaimTopicsRegistry(admin);

        uint256[] memory topics = new uint256[](1);
        topics[0] = KYC_TOPIC;
        trustedIssuersRegistry.addTrustedIssuer(issuer, topics);
        claimTopicsRegistry.addClaimTopic(KYC_TOPIC);

        _registerVerified(user1);
        _registerVerified(user2);

        // Token base con la politica de topics completa.
        token = TokenCloneable(tokenFactory.createToken("Policy Token", "PLC", 18, admin));
        token.setIdentityRegistry(address(identityRegistry));
        token.setTrustedIssuersRegistry(address(trustedIssuersRegistry));
        token.setClaimTopicsRegistry(address(claimTopicsRegistry));
    }

    function _registerVerified(address wallet) internal {
        IdentityCloneable identity = IdentityCloneable(identityFactory.createIdentity(admin));
        bytes memory kycData = abi.encode("KYC", address(identity));
        identity.addClaim(
            KYC_TOPIC,
            1,
            issuer,
            SigUtils.signClaim(ISSUER_PK, address(identity), admin, KYC_TOPIC, 1, kycData, EXPIRES_AT),
            kycData,
            "",
            EXPIRES_AT
        );
        identityRegistry.registerIdentity(wallet, address(identity));
    }

    function _newTokenWithoutTopicsRegistry() internal returns (TokenCloneable t) {
        t = TokenCloneable(tokenFactory.createToken("No Topics", "NTP", 18, admin));
        t.setIdentityRegistry(address(identityRegistry));
        t.setTrustedIssuersRegistry(address(trustedIssuersRegistry));
        // Deliberadamente NO se configura `claimTopicsRegistry`.
    }

    // ================= CU-15: fail-closed =================

    function test_RF011_isVerified_sin_registry_topics_false() public {
        TokenCloneable t = _newTokenWithoutTopicsRegistry();

        assertFalse(t.isVerified(user1), "sin claimTopicsRegistry debe devolver false");
        assertFalse(t.isVerified(user2), "sin claimTopicsRegistry debe devolver false");
    }

    function test_RF011_isVerified_topics_vacios_false() public {
        TokenCloneable t = TokenCloneable(tokenFactory.createToken("Empty Topics", "EMP", 18, admin));
        t.setIdentityRegistry(address(identityRegistry));
        t.setTrustedIssuersRegistry(address(trustedIssuersRegistry));
        ClaimTopicsRegistry emptyRegistry = new ClaimTopicsRegistry(admin); // sin topics
        t.setClaimTopicsRegistry(address(emptyRegistry));

        assertFalse(t.isVerified(user1), "con topics vacios debe devolver false sin revertir");
    }

    function test_RF011_token_recien_creado_por_factory_no_verificado() public {
        TokenCloneable fresh = TokenCloneable(tokenFactory.createToken("Fresh", "FRS", 18, admin));
        fresh.setMaxBurnPerTx(type(uint256).max);

        assertFalse(fresh.isVerified(user1), "token recien creado no verifica a nadie");

        vm.expectRevert("Recipient not verified");
        fresh.mint(user1, 1);
    }

    function test_RF011_configuracion_completa_verifica() public {
        assertTrue(token.isVerified(user1), "con politica completa debe verificar");
        token.setMaxBurnPerTx(type(uint256).max);
        token.mint(user1, 100);
        assertEq(token.balanceOf(user1), 100);
    }

    /// EARS: sin politica, el sistema deniega por defecto (no revierte).
    function test_RF011_isVerified_failclosed_por_defecto() public {
        TokenCloneable t = _newTokenWithoutTopicsRegistry();

        assertFalse(t.isVerified(user1));
        assertFalse(t.isVerified(makeAddr("desconocido")));
    }

    /// EARS: sin politica de topics, `mint` y `transfer` quedan bloqueados.
    function test_RF011_mint_transfer_bloqueados_sin_politica() public {
        // `mint` bloqueado en un token sin politica
        TokenCloneable t = _newTokenWithoutTopicsRegistry();
        t.setMaxBurnPerTx(type(uint256).max);
        vm.expectRevert("Recipient not verified");
        t.mint(user1, 1);

        // `transfer` bloqueado cuando la politica queda vacia (se retira el unico topic exigido)
        token.setMaxBurnPerTx(type(uint256).max);
        token.mint(user1, 100);
        assertTrue(token.isVerified(user1));

        claimTopicsRegistry.removeClaimTopic(KYC_TOPIC);
        assertFalse(token.isVerified(user1), "sin topics exigidos nadie queda verificado");

        vm.expectRevert("Transfer not compliant");
        vm.prank(user1);
        token.transfer(user2, 1);
    }

    // ================= CU-14: extensibilidad de la politica de topics =================

    /// @notice CU-14 EARS `test_RNF005_cambio_topics_afecta_isVerified`: anadir un topic requerido a
    /// un token con holders ya verificados surte efecto de inmediato (sin redeploy): `isVerified`
    /// pasa a `false` y la transferencia revierte; el cambio de politica no altera balances.
    function test_RNF005_cambio_topics_afecta_isVerified() public {
        token.setMaxBurnPerTx(type(uint256).max);
        token.mint(user1, 100 ether);
        assertTrue(token.isVerified(user1), "precondicion: holder verificado");

        claimTopicsRegistry.addClaimTopic(7);

        assertFalse(token.isVerified(user1), "el nuevo topic exigido invalida la verificacion");
        assertFalse(token.isVerified(user2), "el nuevo topic exigido invalida la verificacion");

        vm.prank(user1);
        vm.expectRevert("Transfer not compliant");
        token.transfer(user2, 1 ether);

        assertEq(token.balanceOf(user1), 100 ether, "el cambio de politica no altera balances");
        assertEq(token.balanceOf(user2), 0);
    }

    /// @notice CU-14 EARS `test_RNF005_set_claim_topics_registry_cero_revierte`: fijar a cero el
    /// registry de topics revierte con el literal del contrato y no altera el registry vigente.
    function test_RNF005_set_claim_topics_registry_cero_revierte() public {
        vm.expectRevert(bytes("Invalid registry address"));
        token.setClaimTopicsRegistry(address(0));

        assertEq(
            address(token.claimTopicsRegistry()), address(claimTopicsRegistry), "el registry previo debe conservarse"
        );
    }
}
