// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";
import {TokenCloneFactory} from "../src/TokenCloneFactory.sol";
import {IdentityCloneable} from "../src/IdentityCloneable.sol";
import {IdentityCloneFactory} from "../src/IdentityCloneFactory.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";
import {ClaimTopicsRegistry} from "../src/ClaimTopicsRegistry.sol";
import {SigUtils} from "./helpers/SigUtils.sol";

/**
 * @title PoC_Hallazgos (actualizado en Ciclo 2 / RF-001)
 * @notice Evidencia de verificacion independiente.
 *
 * HISTORIA:
 * - H-01 (critica) se reprodujo originalmente con `test_H01_claim_forjado_firma_vacia`:
 *   `addClaim(1, 1, issuer, "", "", "")` era aceptado y `isVerified() == true`.
 * - Ciclo 2 / RF-001 invierte ese PoC. Ahora `addClaim` exige firma EIP-712 valida,
 *   de modo que el claim forjado **revierte** (`test_H01_...) y un claim firmado
 *   correctamente es aceptado (`test_H01_valid...`).
 * - H-05 sigue reproduciendose: su correccion es del Ciclo 6 / RF-011.
 */
contract PoC_Hallazgos is Test {
    address admin = address(this);

    uint256 constant ISSUER_PK = 0xB0B;
    uint256 constant EXPIRES_AT = 2_000_000_000;

    // H-01 INVERTIDO: un claim forjado con firma VACIA revierte y no se persiste.
    function test_H01_claim_forjado_firma_vacia_revierte() public {
        address attacker = makeAddr("attacker");

        IdentityCloneFactory idFactory = new IdentityCloneFactory(admin);
        IdentityRegistry idRegistry = new IdentityRegistry(admin);
        TrustedIssuersRegistry issuers = new TrustedIssuersRegistry(admin);
        ClaimTopicsRegistry topics = new ClaimTopicsRegistry(admin);
        TokenCloneFactory tokenFactory = new TokenCloneFactory(admin);

        address issuer = vm.addr(ISSUER_PK);
        uint256[] memory t = new uint256[](1);
        t[0] = 1;
        issuers.addTrustedIssuer(issuer, t);
        topics.addClaimTopic(1);

        // El atacante crea su identidad (owner = atacante) e intenta un claim SIN FIRMA
        vm.prank(attacker);
        address identity = idFactory.createIdentity(attacker);

        vm.prank(attacker);
        vm.expectRevert(bytes("Invalid signature length"));
        IdentityCloneable(identity).addClaim(1, 1, issuer, "", "", "", EXPIRES_AT); // firma vacia: ahora revierte

        assertFalse(IdentityCloneable(identity).claimExists(1, issuer), "el claim forjado no debe existir");

        // isVerified sigue siendo false: el token no ve ningun claim
        idRegistry.registerIdentity(attacker, identity);
        address token = tokenFactory.createToken("T", "T", 18, admin);
        TokenCloneable(token).setIdentityRegistry(address(idRegistry));
        TokenCloneable(token).setTrustedIssuersRegistry(address(issuers));
        TokenCloneable(token).setClaimTopicsRegistry(address(topics));

        assertFalse(TokenCloneable(token).isVerified(attacker), "H-01 corregido: no hay claim valido");
    }

    // H-01 (positivo): una firma EIP-712 valida SI crea el claim.
    function test_H01_claim_con_firma_valida_aceptado() public {
        address holder = makeAddr("holder");

        IdentityCloneFactory idFactory = new IdentityCloneFactory(admin);
        address issuer = vm.addr(ISSUER_PK);

        vm.prank(holder);
        address identity = idFactory.createIdentity(holder);

        bytes memory data = abi.encode("KYC", holder);
        bytes memory signature = SigUtils.signClaim(ISSUER_PK, identity, holder, 1, 1, data, EXPIRES_AT);

        vm.prank(holder);
        IdentityCloneable(identity).addClaim(1, 1, issuer, signature, data, "", EXPIRES_AT);

        assertTrue(IdentityCloneable(identity).claimExists(1, issuer), "la firma valida debe aceptarse");
    }

    // H-05 (CORREGIDO en RF-011 / Ciclo 6): sin claimTopicsRegistry, isVerified es fail-closed (false)
    function test_H05_isVerified_fail_closed_ok() public {
        address victim = makeAddr("victim");
        IdentityCloneFactory idFactory = new IdentityCloneFactory(admin);
        IdentityRegistry idRegistry = new IdentityRegistry(admin);
        TokenCloneFactory tokenFactory = new TokenCloneFactory(admin);

        address identity = idFactory.createIdentity(admin); // identidad SIN claims
        idRegistry.registerIdentity(victim, identity);

        address token = tokenFactory.createToken("T2", "T2", 18, admin);
        TokenCloneable(token).setIdentityRegistry(address(idRegistry));
        // NO se configura claimTopicsRegistry a proposito

        assertFalse(
            TokenCloneable(token).isVerified(victim),
            "H-05 corregido: fail-closed sin registry de topics (devolvia true antes de RF-011)"
        );
    }
}
