// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IdentityCloneable} from "../src/IdentityCloneable.sol";
import {IdentityCloneFactory} from "../src/IdentityCloneFactory.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";
import {ClaimTopicsRegistry} from "../src/ClaimTopicsRegistry.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";
import {TokenCloneFactory} from "../src/TokenCloneFactory.sol";
import {SigUtils} from "./helpers/SigUtils.sol";

/**
 * @title RF013_ClaimLifecycleTest
 * @notice Suite RF-013 (Ciclo 8) / CU-17: ciclo de vida del claim — **vigencia** (`expiresAt`) y
 * **revocacion por el issuer**, y su *enforcement* en `TokenCloneable.isVerified`.
 *
 * Semantica de vigencia (D-038): `expiresAt == 0` = **sin caducidad** (perpetuo); con
 * `expiresAt > 0`, el claim es valido mientras `block.timestamp < expiresAt`.
 *
 * Cierra H-08 (auditoria V1): antes el struct `Claim` no tenia vigencia ni estado de revocacion, y
 * solo el titular (`removeClaim`, onlyOwner) podia dejar de usar un claim.
 */
contract RF013_ClaimLifecycleTest is Test {
    uint256 internal constant ISSUER_PK = 0xA11CE;
    uint256 internal constant STRANGER_PK = 0xB0B;
    uint256 internal constant KYC_TOPIC = 1;

    address internal admin = address(this);
    address internal issuer;
    address internal stranger;

    address internal user1;
    address internal user2;

    IdentityCloneFactory internal identityFactory;
    TokenCloneFactory internal tokenFactory;
    IdentityRegistry internal identityRegistry;
    TrustedIssuersRegistry internal trustedIssuersRegistry;
    ClaimTopicsRegistry internal claimTopicsRegistry;
    TokenCloneable internal token;

    mapping(address => IdentityCloneable) internal identities;

    event ClaimAdded(
        uint256 indexed topic,
        uint256 scheme,
        address indexed issuer,
        bytes signature,
        bytes data,
        string uri,
        uint256 expiresAt
    );
    event ClaimRevoked(uint256 indexed topic, address indexed issuer);

    function setUp() public {
        issuer = vm.addr(ISSUER_PK);
        stranger = vm.addr(STRANGER_PK);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        identityFactory = new IdentityCloneFactory(admin);
        tokenFactory = new TokenCloneFactory(admin);

        identityRegistry = new IdentityRegistry(admin);
        trustedIssuersRegistry = new TrustedIssuersRegistry(admin);
        claimTopicsRegistry = new ClaimTopicsRegistry(admin);

        uint256[] memory topics = new uint256[](1);
        topics[0] = KYC_TOPIC;
        trustedIssuersRegistry.addTrustedIssuer(issuer, topics);
        claimTopicsRegistry.addClaimTopic(KYC_TOPIC);

        token = TokenCloneable(tokenFactory.createToken("Lifecycle Token", "LFC", 18, admin));
        token.setIdentityRegistry(address(identityRegistry));
        token.setTrustedIssuersRegistry(address(trustedIssuersRegistry));
        token.setClaimTopicsRegistry(address(claimTopicsRegistry));
        token.setMaxBurnPerTx(type(uint256).max);

        // Identidades propiedad del propio titular (escenario real).
        _registerWallet(user1);
        _registerWallet(user2);
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    /// @dev Crea una identidad propiedad del wallet y la registra en el `IdentityRegistry`.
    function _registerWallet(address wallet) internal {
        IdentityCloneable identity = IdentityCloneable(identityFactory.createIdentity(wallet));
        identities[wallet] = identity;
        identityRegistry.registerIdentity(wallet, address(identity));
    }

    /// @dev Emite (o renueva) el claim de KYC del wallet, firmado EIP-712 por `issuer`.
    /// Ciclo 8c: firma con el `claimNonce` vigente de `(topic, issuer)` (0 en el alta; >0 si ya se revoco).
    function _attest(address wallet, bytes memory data, string memory uri, uint256 expiresAt) internal {
        IdentityCloneable identity = identities[wallet];
        uint256 nonce = identity.claimNonce(KYC_TOPIC, issuer);
        bytes memory sig =
            SigUtils.signClaim(ISSUER_PK, address(identity), wallet, KYC_TOPIC, 1, data, expiresAt, nonce);
        vm.prank(wallet);
        identity.addClaim(KYC_TOPIC, 1, issuer, sig, data, uri, expiresAt);
    }

    /// @dev Ciclo 8c: nonce firmado vigente para el par `(topic, issuer)` de ese wallet.
    function _nonce(address wallet) internal view returns (uint256) {
        return identities[wallet].claimNonce(KYC_TOPIC, issuer);
    }

    /// @dev Firma EIP-712 de `issuer` para un `nonce` explicito.
    function _sign(address wallet, bytes memory data, uint256 expiresAt, uint256 nonce)
        internal
        view
        returns (bytes memory)
    {
        return SigUtils.signClaim(ISSUER_PK, address(identities[wallet]), wallet, KYC_TOPIC, 1, data, expiresAt, nonce);
    }

    function _claimData(address wallet) internal view returns (bytes memory) {
        return abi.encode("KYC", wallet);
    }

    /// @dev Lee solo el flag `revoked` de la tupla de 8 campos de `getClaim`.
    function _revoked(address wallet) internal view returns (bool revoked) {
        (,,,,,,, revoked) = identities[wallet].getClaim(KYC_TOPIC, issuer);
    }

    // ------------------------------------------------------------------
    // CU-17 — Criterios Gherkin
    // ------------------------------------------------------------------

    /// 1. Claim vigente (`expiresAt` futuro, `revoked == false`) ⇒ `isVerified == true`.
    function test_RF013_claim_vigente_isVerified_true() public {
        uint256 expiresAt = block.timestamp + 30 days;
        _attest(user1, _claimData(user1), "https://kyc.example.com", expiresAt);

        assertTrue(identities[user1].claimExists(KYC_TOPIC, issuer));
        assertTrue(identities[user1].hasValidClaim(KYC_TOPIC, issuer), "claim vigente");
        assertFalse(_revoked(user1));
        assertTrue(token.isVerified(user1), "un claim vigente verifica al titular");
    }

    /// D-038: `expiresAt == 0` = sin caducidad (perpetuo).
    function test_RF013_claim_sin_caducidad_perpetuo_isVerified_true() public {
        _attest(user1, _claimData(user1), "uri", 0);

        assertTrue(identities[user1].hasValidClaim(KYC_TOPIC, issuer));
        assertTrue(token.isVerified(user1));

        // Sigue valido muy avanzado el tiempo.
        vm.warp(block.timestamp + 3650 days);
        assertTrue(token.isVerified(user1), "expiresAt == 0 nunca caduca");
    }

    /// 2. Claim expirado (`block.timestamp >= expiresAt`) ⇒ `false` y transfer revertida.
    function test_RF013_claim_expirado_isVerified_false() public {
        uint256 expiresAt = block.timestamp + 30 days;
        _attest(user1, _claimData(user1), "uri", expiresAt);
        _attest(user2, _claimData(user2), "uri", 0); // user2 perpetuo, para aislar la caducidad

        token.mint(user1, 100);
        assertTrue(token.isVerified(user1), "vigente antes de vencer");

        // Justo en el limite: `block.timestamp == expiresAt` ya no es valido.
        vm.warp(expiresAt);
        assertFalse(identities[user1].hasValidClaim(KYC_TOPIC, issuer), "vencido en el limite");
        assertFalse(token.isVerified(user1), "expirado => false");

        vm.expectRevert("Transfer not compliant");
        vm.prank(user1);
        token.transfer(user2, 1);

        // Un instante antes si era valido (frontera D-038).
        vm.warp(expiresAt - 1);
        assertTrue(token.isVerified(user1), "un segundo antes sigue vigente");
    }

    /// 3. Revocacion por el issuer ⇒ `revoked == true`, `ClaimRevoked` e `isVerified == false`.
    function test_RF013_claim_revocado_por_issuer_isVerified_false() public {
        uint256 expiresAt = block.timestamp + 30 days;
        _attest(user1, _claimData(user1), "uri", expiresAt);
        assertTrue(token.isVerified(user1));

        vm.expectEmit(true, true, false, false, address(identities[user1]));
        emit ClaimRevoked(KYC_TOPIC, issuer);

        vm.prank(issuer);
        identities[user1].revokeClaim(KYC_TOPIC, issuer);

        assertTrue(_revoked(user1), "getClaim refleja revoked == true");
        assertTrue(identities[user1].claimExists(KYC_TOPIC, issuer), "el claim no se borra");
        assertFalse(identities[user1].hasValidClaim(KYC_TOPIC, issuer));
        assertFalse(token.isVerified(user1), "revocado => false");
    }

    /// 4. Solo el issuer puede revocar; un tercero (ni el titular) puede.
    function test_RF013_revocar_solo_issuer_revierte() public {
        uint256 expiresAt = block.timestamp + 30 days;
        _attest(user1, _claimData(user1), "uri", expiresAt);

        // Un tercero cualquiera.
        vm.prank(stranger);
        vm.expectRevert("Only issuer can revoke");
        identities[user1].revokeClaim(KYC_TOPIC, issuer);

        // El propio titular (owner de la identidad) tampoco puede revocar en nombre del issuer.
        vm.prank(user1);
        vm.expectRevert("Only issuer can revoke");
        identities[user1].revokeClaim(KYC_TOPIC, issuer);

        assertFalse(_revoked(user1));
        assertTrue(token.isVerified(user1), "el claim permanece vigente");
    }

    /// 5. Renovacion con nueva firma ⇒ `expiresAt` nuevo y `revoked == false`.
    function test_RF013_renovacion_actualiza_vigencia() public {
        uint256 firstExpiry = block.timestamp + 1 days;
        _attest(user1, _claimData(user1), "uri-v1", firstExpiry);

        vm.prank(issuer);
        identities[user1].revokeClaim(KYC_TOPIC, issuer);
        assertFalse(token.isVerified(user1));

        // Nueva firma del issuer con vigencia nueva (D-020/D-018).
        uint256 newExpiry = block.timestamp + 365 days;
        _attest(user1, abi.encode("KYC renovado", user1), "uri-v2", newExpiry);

        (,,,,,, uint256 expiresAt, bool revoked) = identities[user1].getClaim(KYC_TOPIC, issuer);
        assertEq(expiresAt, newExpiry, "la vigencia se actualiza");
        assertFalse(revoked, "la renovacion limpia revoked");
        assertTrue(token.isVerified(user1), "vuelve a estar verificado");
    }

    /// Complementario de 5: renovar tras expirar tambien reactiva el claim.
    function test_RF013_renovacion_tras_expiracion_reactiva() public {
        uint256 firstExpiry = block.timestamp + 1 days;
        _attest(user1, _claimData(user1), "uri-v1", firstExpiry);

        vm.warp(firstExpiry);
        assertFalse(token.isVerified(user1));

        uint256 newExpiry = block.timestamp + 365 days;
        _attest(user1, _claimData(user1), "uri-v2", newExpiry);

        assertTrue(identities[user1].hasValidClaim(KYC_TOPIC, issuer));
        assertTrue(token.isVerified(user1));
    }

    /// 6. Revocar un claim inexistente revierte.
    function test_RF013_claim_inexistente_revierte() public {
        assertFalse(identities[user1].hasValidClaim(KYC_TOPIC, issuer));

        vm.prank(issuer);
        vm.expectRevert("Claim does not exist");
        identities[user1].revokeClaim(KYC_TOPIC, issuer);

        // Tambien si lo intenta un tercero sobre un claim inexistente (existencia primero).
        vm.prank(stranger);
        vm.expectRevert("Claim does not exist");
        identities[user1].revokeClaim(KYC_TOPIC, issuer);

        assertFalse(token.isVerified(user1));
    }

    // ------------------------------------------------------------------
    // CU-17 — Restricciones EARS
    // ------------------------------------------------------------------

    /// EARS 1: mientras `block.timestamp >= expiresAt`, `isVerified` rechaza el claim.
    function test_RF013_isVerified_rechaza_vencidos() public {
        uint256 expiresAt = block.timestamp + 10 days;
        _attest(user1, _claimData(user1), "uri", expiresAt);

        assertTrue(token.isVerified(user1));
        assertTrue(token.isVerified(user1), "estable antes del vencimiento");

        vm.warp(expiresAt);
        assertFalse(token.isVerified(user1), "en el limite ya vencido (>=)");

        vm.warp(expiresAt + 100 days);
        assertFalse(token.isVerified(user1), "pasado el vencimiento");

        // El claim sigue almacenado aunque no sea valido (no se borra solo).
        assertTrue(identities[user1].claimExists(KYC_TOPIC, issuer));
    }

    /// EARS 2: la revocacion emite `ClaimRevoked` y conserva el historico de `ClaimAdded`.
    function test_RF013_revocacion_emite_evento_y_conserva_historico() public {
        bytes memory data = _claimData(user1);
        string memory uri = "https://kyc.example.com/history";
        uint256 expiresAt = block.timestamp + 30 days;
        bytes memory sig = SigUtils.signClaim(
            ISSUER_PK, address(identities[user1]), user1, KYC_TOPIC, 1, data, expiresAt, _nonce(user1)
        );

        // Historico: `ClaimAdded` queda registrado en la cadena y no se borra al revocar.
        vm.expectEmit(true, true, true, true, address(identities[user1]));
        emit ClaimAdded(KYC_TOPIC, 1, issuer, sig, data, uri, expiresAt);
        vm.prank(user1);
        identities[user1].addClaim(KYC_TOPIC, 1, issuer, sig, data, uri, expiresAt);

        vm.expectEmit(true, true, false, false, address(identities[user1]));
        emit ClaimRevoked(KYC_TOPIC, issuer);
        vm.prank(issuer);
        identities[user1].revokeClaim(KYC_TOPIC, issuer);

        // El claim revocado conserva firma, datos y uri: solo cambia `revoked`.
        (
            uint256 topic,
            uint256 scheme,
            address claimIssuer,
            bytes memory storedSig,
            bytes memory storedData,
            string memory storedUri,
            uint256 storedExpiry,
            bool revoked
        ) = identities[user1].getClaim(KYC_TOPIC, issuer);

        assertEq(topic, KYC_TOPIC);
        assertEq(scheme, 1);
        assertEq(claimIssuer, issuer);
        assertEq(storedSig, sig, "la firma historica se conserva");
        assertEq(storedData, data, "los datos se conservan");
        assertEq(storedUri, uri, "la uri se conserva");
        assertEq(storedExpiry, expiresAt, "el expiresAt firmado se conserva");
        assertTrue(revoked, "revoked == true");

        // El issuer sigue indexado para el topic (no se retira de `topicIssuers`).
        address[] memory issuers = identities[user1].getClaimIssuersForTopic(KYC_TOPIC);
        assertEq(issuers.length, 1);
        assertEq(issuers[0], issuer);
    }

    /// EARS 3: el titular no puede reactivar un claim revocado sin una nueva firma del issuer.
    function test_RF013_revocacion_no_reactivable_por_titular() public {
        _attest(user1, _claimData(user1), "uri", block.timestamp + 30 days);

        vm.prank(issuer);
        identities[user1].revokeClaim(KYC_TOPIC, issuer);
        assertFalse(token.isVerified(user1));

        // El titular intenta reactivar aportando una firma que NO es del issuer: se rechaza
        // (firmada con el nonce vigente para aislar la comprobacion del firmante).
        uint256 forgedExpiry = block.timestamp + 60 days;
        bytes memory forgedSig = SigUtils.signClaim(
            STRANGER_PK, address(identities[user1]), user1, KYC_TOPIC, 1, _claimData(user1), forgedExpiry, _nonce(user1)
        );
        vm.prank(user1);
        vm.expectRevert("Signature signer mismatch");
        identities[user1].addClaim(KYC_TOPIC, 1, issuer, forgedSig, _claimData(user1), "uri", forgedExpiry);

        assertTrue(_revoked(user1), "sigue revocado");
        assertFalse(identities[user1].hasValidClaim(KYC_TOPIC, issuer));
        assertFalse(token.isVerified(user1));

        // El titular conserva `removeClaim`, pero borrar no reactiva: sin nueva firma sigue sin verificar.
        vm.prank(user1);
        identities[user1].removeClaim(KYC_TOPIC, issuer);
        assertFalse(identities[user1].claimExists(KYC_TOPIC, issuer));
        assertFalse(token.isVerified(user1));
    }

    // ------------------------------------------------------------------
    // Ciclo 8c — nonce firmado: cierra el bypass de la revocacion por replay
    // ------------------------------------------------------------------

    /// D-046/D-050: tras revocar, la **firma original** ya no sirve para reactivar el claim.
    function test_RF013_revocacion_replay_firma_original_revierte() public {
        bytes memory data = _claimData(user1);
        uint256 expiresAt = block.timestamp + 30 days;

        // Firma original del issuer (nonce 0) y alta del claim.
        bytes memory originalSig = _sign(user1, data, expiresAt, 0);
        vm.prank(user1);
        identities[user1].addClaim(KYC_TOPIC, 1, issuer, originalSig, data, "uri", expiresAt);
        assertTrue(token.isVerified(user1));

        vm.prank(issuer);
        identities[user1].revokeClaim(KYC_TOPIC, issuer);
        assertFalse(token.isVerified(user1));

        // El titular reintroduce exactamente la firma original (replay): debe revertir.
        vm.prank(user1);
        vm.expectRevert("Signature signer mismatch");
        identities[user1].addClaim(KYC_TOPIC, 1, issuer, originalSig, data, "uri", expiresAt);

        // El claim sigue revocado y el titular sin verificar.
        assertTrue(_revoked(user1), "la revocacion es definitiva frente al replay");
        assertFalse(identities[user1].hasValidClaim(KYC_TOPIC, issuer));
        assertFalse(token.isVerified(user1));
    }

    /// El nonce de `(topic, issuer)` pasa de 0 a 1 al revocar (y solo entonces).
    function test_RF013_revocacion_incrementa_nonce() public {
        _attest(user1, _claimData(user1), "uri", block.timestamp + 30 days);
        assertEq(_nonce(user1), 0, "nonce inicial");

        vm.prank(issuer);
        identities[user1].revokeClaim(KYC_TOPIC, issuer);
        assertEq(_nonce(user1), 1, "revocar incrementa el nonce");

        // Una segunda revocacion del mismo claim lo vuelve a incrementar (no hay techo).
        vm.prank(issuer);
        identities[user1].revokeClaim(KYC_TOPIC, issuer);
        assertEq(_nonce(user1), 2, "cada revocacion incrementa el nonce");

        // El nonce es por par `(topic, issuer)`: otro topic no se ve afectado.
        assertEq(identities[user1].claimNonce(2, issuer), 0, "nonce aislado por topic");
    }

    /// Reactivacion legitima: el issuer firma con el nonce nuevo (1) y el claim vuelve a ser valido.
    function test_RF013_reactivacion_con_nonce_nuevo_ok() public {
        bytes memory data = _claimData(user1);
        uint256 expiresAt = block.timestamp + 30 days;
        _attest(user1, data, "uri-v1", expiresAt);

        vm.prank(issuer);
        identities[user1].revokeClaim(KYC_TOPIC, issuer);
        assertEq(_nonce(user1), 1);
        assertFalse(token.isVerified(user1));

        // Nueva firma del issuer con el nonce incrementado.
        uint256 newExpiry = block.timestamp + 365 days;
        bytes memory newSig = _sign(user1, data, newExpiry, 1);
        vm.prank(user1);
        identities[user1].addClaim(KYC_TOPIC, 1, issuer, newSig, data, "uri-v2", newExpiry);

        (,,,,,, uint256 storedExpiry, bool revoked) = identities[user1].getClaim(KYC_TOPIC, issuer);
        assertEq(storedExpiry, newExpiry, "la vigencia se actualiza");
        assertFalse(revoked, "la firma con el nonce nuevo reactiva el claim");
        assertTrue(identities[user1].hasValidClaim(KYC_TOPIC, issuer));
        assertTrue(token.isVerified(user1), "vuelve a estar verificado");
    }

    /// D-018 intacto: sin revocacion, reaplicar la misma firma (nonce 0) sigue siendo idempotente.
    function test_RF013_renovacion_sin_revocar_sigue_idempotente() public {
        bytes memory data = _claimData(user1);
        uint256 expiresAt = block.timestamp + 30 days;
        bytes memory sig = _sign(user1, data, expiresAt, 0);

        vm.prank(user1);
        identities[user1].addClaim(KYC_TOPIC, 1, issuer, sig, data, "uri", expiresAt);

        // Reaplicar la MISMA firma valida (mismo nonce 0) no revierte y no duplica al issuer.
        vm.prank(user1);
        identities[user1].addClaim(KYC_TOPIC, 1, issuer, sig, data, "uri", expiresAt);

        assertEq(_nonce(user1), 0, "el alta no incrementa el nonce");
        assertTrue(identities[user1].hasValidClaim(KYC_TOPIC, issuer));
        assertTrue(token.isVerified(user1));
        assertEq(identities[user1].getClaimIssuersForTopic(KYC_TOPIC).length, 1, "issuer sin duplicar");
    }

    /// El `nonce` forma parte del digest: una firma con el nonce antiguo no vale contra el nuevo.
    function test_RF013_digest_incluye_nonce() public {
        bytes memory data = _claimData(user1);
        uint256 expiresAt = block.timestamp + 30 days;

        bytes32 digestNonce0 = SigUtils.claimDigest(address(identities[user1]), user1, KYC_TOPIC, 1, data, expiresAt, 0);
        bytes32 digestNonce1 = SigUtils.claimDigest(address(identities[user1]), user1, KYC_TOPIC, 1, data, expiresAt, 1);
        assertTrue(digestNonce0 != digestNonce1, "el digest cambia con el nonce");

        _attest(user1, data, "uri", expiresAt);
        vm.prank(issuer);
        identities[user1].revokeClaim(KYC_TOPIC, issuer);

        // Firma NUEVA del issuer, pero construida sobre el nonce 0: no verifica cuando el nonce es 1.
        bytes memory sigNonce0 = _sign(user1, data, expiresAt, 0);
        vm.prank(user1);
        vm.expectRevert("Signature signer mismatch");
        identities[user1].addClaim(KYC_TOPIC, 1, issuer, sigNonce0, data, "uri", expiresAt);
    }
}
