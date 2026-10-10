// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IdentityCloneable} from "../src/IdentityCloneable.sol";
import {IdentityCloneFactory} from "../src/IdentityCloneFactory.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";
import {TokenCloneFactory} from "../src/TokenCloneFactory.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";
import {ClaimTopicsRegistry} from "../src/ClaimTopicsRegistry.sol";
import {SigUtils} from "./helpers/SigUtils.sol";

/**
 * @title IdentityCloneableRF001Test
 * @notice Suite RF-001 (CU-02/CU-03): verificacion criptografica EIP-712 de claims.
 *
 * Invierte el PoC H-01: una firma vacia o invalida revierte y no escribe estado.
 * Cubre ademas la politica de reintento (D-018) y el limite de alcance de la
 * verificacion (D-025: la autorizacion de issuer por topic la impone el token).
 */
contract IdentityCloneableRF001Test is Test {
    IdentityCloneFactory internal factory;
    IdentityCloneable internal identity;

    uint256 internal constant OWNER_PK = 0xA11CE;
    uint256 internal constant ISSUER_PK = 0xB0B;
    uint256 internal constant ISSUER2_PK = 0xC0FFEE;
    uint256 internal constant EXPIRES_AT = 2_000_000_000;

    address internal owner;
    address internal issuer;
    address internal issuer2;

    event ClaimAdded(
        uint256 indexed topic,
        uint256 scheme,
        address indexed issuer,
        bytes signature,
        bytes data,
        string uri,
        uint256 expiresAt
    );

    function setUp() public {
        owner = vm.addr(OWNER_PK);
        issuer = vm.addr(ISSUER_PK);
        issuer2 = vm.addr(ISSUER2_PK);

        factory = new IdentityCloneFactory(address(this));
        identity = IdentityCloneable(factory.createIdentity(owner));
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    /// @dev AF-03: la firma cubre el `uri` (via `uriHash`), igual que el `data`.
    function _sign(uint256 pk, uint256 topic, uint256 scheme, bytes memory data, uint256 expiresAt, string memory uri)
        internal
        view
        returns (bytes memory)
    {
        return SigUtils.signClaim(pk, address(identity), owner, topic, scheme, data, expiresAt, 0, uri);
    }

    function _add(uint256 topic, address _issuer, uint256 pk, bytes memory data, string memory uri, uint256 expiresAt)
        internal
        returns (bytes32)
    {
        bytes memory sig = _sign(pk, topic, 1, data, expiresAt, uri);
        vm.prank(owner);
        return identity.addClaim(topic, 1, _issuer, sig, data, uri, expiresAt);
    }

    // ------------------------------------------------------------------
    // Positivos (CU-02)
    // ------------------------------------------------------------------

    function test_RF001_addClaim_con_firma_valida() public {
        bytes memory data = abi.encode("KYC", owner);
        bytes memory sig = _sign(ISSUER_PK, 1, 1, data, EXPIRES_AT, "https://kyc.example.com");

        vm.expectEmit(true, true, true, true, address(identity));
        emit ClaimAdded(1, 1, issuer, sig, data, "https://kyc.example.com", EXPIRES_AT);

        vm.prank(owner);
        bytes32 claimId = identity.addClaim(1, 1, issuer, sig, data, "https://kyc.example.com", EXPIRES_AT);

        assertEq(claimId, keccak256(abi.encode(issuer, uint256(1))), "claimId determinista");
        assertTrue(identity.claimExists(1, issuer), "claim debe existir");

        (
            uint256 topic,
            uint256 scheme,
            address returnedIssuer,
            bytes memory returnedSig,
            bytes memory returnedData,
            string memory returnedUri,
            uint256 expiresAt,
            bool revoked
        ) = identity.getClaim(1, issuer);

        assertEq(topic, 1);
        assertEq(scheme, 1);
        assertEq(returnedIssuer, issuer);
        assertEq(returnedSig, sig);
        assertEq(returnedData, data);
        assertEq(returnedUri, "https://kyc.example.com");
        assertEq(expiresAt, EXPIRES_AT, "expiresAt firmado y almacenado");
        assertFalse(revoked, "un claim recien anadido no esta revocado");
    }

    function test_RF001_addClaim_emite_claimId_estable() public {
        bytes32 idA = _add(1, issuer, ISSUER_PK, abi.encode("KYC"), "uri-a", EXPIRES_AT);
        bytes32 idB = _add(2, issuer2, ISSUER2_PK, abi.encode("AML"), "uri-b", EXPIRES_AT);

        assertEq(idA, keccak256(abi.encode(issuer, uint256(1))));
        assertEq(idB, keccak256(abi.encode(issuer2, uint256(2))));
        assertTrue(idA != idB);
    }

    function test_RF001_addClaim_actualiza_indice_topicIssuers() public {
        _add(1, issuer, ISSUER_PK, abi.encode("KYC"), "uri", EXPIRES_AT);

        address[] memory issuers = identity.getClaimIssuersForTopic(1);
        assertEq(issuers.length, 1);
        assertEq(issuers[0], issuer);

        // Reintento valido: no duplica al issuer en el array (D-018)
        _add(1, issuer, ISSUER_PK, abi.encode("KYC renovado"), "uri2", EXPIRES_AT + 1 days);
        issuers = identity.getClaimIssuersForTopic(1);
        assertEq(issuers.length, 1, "el issuer no se duplica al renovar");
        assertEq(issuers[0], issuer);
    }

    function test_RF001_addClaim_only_owner_revierte() public {
        bytes memory data = abi.encode("KYC", owner);
        bytes memory sig = _sign(ISSUER_PK, 1, 1, data, EXPIRES_AT, "uri");
        address stranger = makeAddr("stranger");

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", stranger));
        identity.addClaim(1, 1, issuer, sig, data, "uri", EXPIRES_AT);

        assertFalse(identity.claimExists(1, issuer));
    }

    function test_RF001_addClaim_reintento_sobrescribe_renueva() public {
        bytes memory oldData = abi.encode("KYC v1");
        _add(1, issuer, ISSUER_PK, oldData, "uri-v1", EXPIRES_AT);

        bytes memory newData = abi.encode("KYC v2");
        uint256 newExpiry = EXPIRES_AT + 365 days;
        _add(1, issuer, ISSUER_PK, newData, "uri-v2", newExpiry);

        (
            ,,
            address returnedIssuer,,
            bytes memory returnedData,
            string memory returnedUri,
            uint256 expiresAt,
            bool revoked
        ) = identity.getClaim(1, issuer);

        assertEq(returnedIssuer, issuer);
        assertEq(returnedData, newData, "los datos se sobrescriben");
        assertEq(returnedUri, "uri-v2", "la uri se sobrescribe");
        assertEq(expiresAt, newExpiry, "la vigencia se renueva");
        assertFalse(revoked, "la renovacion limpia el estado de revocacion");
        assertEq(identity.getClaimIssuersForTopic(1).length, 1, "sin duplicar issuer");
    }

    function test_RF001_addClaim_reintento_con_firma_invalida_no_sobrescribe() public {
        bytes memory oldData = abi.encode("KYC original");
        _add(1, issuer, ISSUER_PK, oldData, "uri-original", EXPIRES_AT);

        // Firma de otra clave para los datos nuevos
        bytes memory newData = abi.encode("KYC manipulado");
        bytes memory badSig = _sign(ISSUER2_PK, 1, 1, newData, EXPIRES_AT + 1 days, "uri-nueva");

        vm.prank(owner);
        vm.expectRevert(bytes("Signature signer mismatch"));
        identity.addClaim(1, 1, issuer, badSig, newData, "uri-nueva", EXPIRES_AT + 1 days);

        (,,,, bytes memory returnedData, string memory returnedUri,,) = identity.getClaim(1, issuer);
        assertEq(returnedData, oldData, "el claim previo no se altera");
        assertEq(returnedUri, "uri-original");
    }

    // ------------------------------------------------------------------
    // Negativos (CU-03) — incluye la inversion del PoC H-01
    // ------------------------------------------------------------------

    function test_RF001_addClaim_firma_vacia_revierte() public {
        // PoC H-01 invertido: antes una firma vacia era aceptada y creaba el claim.
        bytes memory data = abi.encode("KYC", owner);

        vm.prank(owner);
        vm.expectRevert(bytes("Invalid signature length"));
        identity.addClaim(1, 1, issuer, "", data, "uri", EXPIRES_AT);

        assertFalse(identity.claimExists(1, issuer), "no debe persistir el claim forjado");
        assertEq(identity.getClaimIssuersForTopic(1).length, 0);
    }

    function test_RF001_addClaim_firma_longitud_invalida_revierte() public {
        bytes memory data = abi.encode("KYC", owner);
        bytes memory sig64 = new bytes(64);

        vm.prank(owner);
        vm.expectRevert(bytes("Invalid signature length"));
        identity.addClaim(1, 1, issuer, sig64, data, "uri", EXPIRES_AT);

        assertFalse(identity.claimExists(1, issuer));
    }

    function test_RF001_addClaim_firma_de_otra_clave_revierte() public {
        bytes memory data = abi.encode("KYC", owner);
        bytes memory sig = _sign(ISSUER2_PK, 1, 1, data, EXPIRES_AT, "uri"); // firma de issuer2

        vm.prank(owner);
        vm.expectRevert(bytes("Signature signer mismatch"));
        identity.addClaim(1, 1, issuer, sig, data, "uri", EXPIRES_AT);

        assertFalse(identity.claimExists(1, issuer));
    }

    function test_RF001_addClaim_walletOwner_distinto_revierte() public {
        // Firma valida, pero emitida para otro titular: no puede reutilizarse aqui.
        address otherWallet = makeAddr("otherWallet");
        bytes memory data = abi.encode("KYC", owner);
        bytes memory sig =
            SigUtils.signClaim(ISSUER_PK, address(identity), otherWallet, 1, 1, data, EXPIRES_AT, 0, "uri");

        vm.prank(owner);
        vm.expectRevert(bytes("Signature signer mismatch"));
        identity.addClaim(1, 1, issuer, sig, data, "uri", EXPIRES_AT);

        assertFalse(identity.claimExists(1, issuer));
    }

    function test_RF001_addClaim_data_manipulada_revierte() public {
        bytes memory original = abi.encode("KYC original");
        bytes memory sig = _sign(ISSUER_PK, 1, 1, original, EXPIRES_AT, "uri");
        bytes memory manipulated = abi.encode("KYC manipulado");

        vm.prank(owner);
        vm.expectRevert(bytes("Signature signer mismatch"));
        identity.addClaim(1, 1, issuer, sig, manipulated, "uri", EXPIRES_AT);

        assertFalse(identity.claimExists(1, issuer));
    }

    function test_RF001_addClaim_topic_manipulado_revierte() public {
        bytes memory data = abi.encode("KYC");
        bytes memory sig = _sign(ISSUER_PK, 1, 1, data, EXPIRES_AT, "uri");

        vm.prank(owner);
        vm.expectRevert(bytes("Signature signer mismatch"));
        identity.addClaim(2, 1, issuer, sig, data, "uri", EXPIRES_AT); // topic 2 no firmado
    }

    function test_RF001_addClaim_expiresAt_manipulado_revierte() public {
        bytes memory data = abi.encode("KYC");
        bytes memory sig = _sign(ISSUER_PK, 1, 1, data, EXPIRES_AT, "uri");

        vm.prank(owner);
        vm.expectRevert(bytes("Signature signer mismatch"));
        identity.addClaim(1, 1, issuer, sig, data, "uri", EXPIRES_AT + 1); // vigencia alterada
    }

    function test_RF001_addClaim_scheme_no_soportado_revierte() public {
        bytes memory data = abi.encode("KYC", owner);
        bytes memory sig = _sign(ISSUER_PK, 1, 1, data, EXPIRES_AT, "uri");

        vm.prank(owner);
        vm.expectRevert(bytes("Unsupported scheme"));
        identity.addClaim(1, 2, issuer, sig, data, "uri", EXPIRES_AT);

        vm.prank(owner);
        vm.expectRevert(bytes("Unsupported scheme"));
        identity.addClaim(1, 0, issuer, sig, data, "uri", EXPIRES_AT);

        assertFalse(identity.claimExists(1, issuer));
    }

    function test_RF001_addClaim_issuer_cero_revierte() public {
        bytes memory data = abi.encode("KYC", owner);

        vm.prank(owner);
        vm.expectRevert(bytes("Invalid issuer address"));
        identity.addClaim(1, 1, address(0), "", data, "uri", EXPIRES_AT);

        assertFalse(identity.claimExists(1, address(0)));
    }

    function test_RF001_addClaim_ecrecover_cero_revierte() public {
        bytes memory data = abi.encode("KYC", owner);
        // v = 26 no es valido: ECDSA devuelve address(0)
        bytes memory malformed = abi.encodePacked(bytes32(uint256(1)), bytes32(uint256(2)), uint8(26));

        vm.prank(owner);
        vm.expectRevert(bytes("Invalid signature"));
        identity.addClaim(1, 1, issuer, malformed, data, "uri", EXPIRES_AT);
    }

    function test_RF001_addClaim_firma_maleable_s_alto_revierte() public {
        bytes memory data = abi.encode("KYC", owner);
        bytes32 digest = SigUtils.claimDigest(address(identity), owner, 1, 1, data, EXPIRES_AT, 0, "uri");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ISSUER_PK, digest);

        // Maleabilidad clasica: (r, n-s, v^1) tambien es valida para ecrecover.
        uint256 n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
        bytes32 highS = bytes32(n - uint256(s));
        uint8 flippedV = v == 27 ? 28 : 27;
        bytes memory malleable = abi.encodePacked(r, highS, flippedV);

        vm.prank(owner);
        vm.expectRevert(bytes("Invalid signature"));
        identity.addClaim(1, 1, issuer, malleable, data, "uri", EXPIRES_AT);
    }

    function test_RF001_addClaim_no_escribe_estado_en_fallo() public {
        bytes memory data = abi.encode("KYC", owner);
        bytes memory badSig = _sign(ISSUER2_PK, 1, 1, data, EXPIRES_AT, "uri");

        vm.prank(owner);
        vm.expectRevert(bytes("Signature signer mismatch"));
        identity.addClaim(1, 1, issuer, badSig, data, "uri", EXPIRES_AT);

        assertFalse(identity.claimExists(1, issuer), "claims sin cambios");
        assertEq(identity.getClaimIssuersForTopic(1).length, 0, "topicIssuers sin cambios");

        // Tras el fallo, un claim valido sigue funcionando
        _add(1, issuer, ISSUER_PK, data, "uri", EXPIRES_AT);
        assertTrue(identity.claimExists(1, issuer));
    }

    // ------------------------------------------------------------------
    // Vinculacion de dominio (CU-02 EARS)
    // ------------------------------------------------------------------

    function test_RF001_addClaim_digest_vincula_verifyingContract() public {
        IdentityCloneable otherIdentity = IdentityCloneable(factory.createIdentity(owner));
        bytes memory data = abi.encode("KYC", owner);

        // Firma generada para OTRA identidad (otro verifyingContract)
        bytes memory sig =
            SigUtils.signClaim(ISSUER_PK, address(otherIdentity), owner, 1, 1, data, EXPIRES_AT, 0, "uri");

        vm.prank(owner);
        vm.expectRevert(bytes("Signature signer mismatch"));
        identity.addClaim(1, 1, issuer, sig, data, "uri", EXPIRES_AT);

        assertFalse(identity.claimExists(1, issuer));
    }

    function test_RF001_addClaim_digest_vincula_chainId() public {
        bytes memory data = abi.encode("KYC", owner);
        bytes memory sig = _sign(ISSUER_PK, 1, 1, data, EXPIRES_AT, "uri");

        // La firma se creo para el chainId original (31337 en tests)
        vm.chainId(999);

        vm.prank(owner);
        vm.expectRevert(bytes("Signature signer mismatch"));
        identity.addClaim(1, 1, issuer, sig, data, "uri", EXPIRES_AT);

        assertFalse(identity.claimExists(1, issuer));
    }

    // ------------------------------------------------------------------
    // D-025: la autorizacion de issuer por topic la impone el token
    // ------------------------------------------------------------------

    function test_RF001_issuer_no_autorizado_para_topic_no_verifica() public {
        // El issuer tiene una firma EIP-712 valida, pero el token no lo reconoce
        // para el topic 1: isVerified debe ser false (D-025).
        _add(1, issuer, ISSUER_PK, abi.encode("KYC"), "uri", EXPIRES_AT);

        IdentityRegistry idRegistry = new IdentityRegistry(address(this));
        TrustedIssuersRegistry trustedIssuers = new TrustedIssuersRegistry(address(this));
        ClaimTopicsRegistry topicsRegistry = new ClaimTopicsRegistry(address(this));
        TokenCloneFactory tokenFactory = new TokenCloneFactory(address(this));

        topicsRegistry.addClaimTopic(1);

        uint256[] memory topicList = new uint256[](1);
        topicList[0] = 1;
        // Solo issuer2 es confiable para el topic 1
        trustedIssuers.addTrustedIssuer(issuer2, topicList);

        idRegistry.registerIdentity(owner, address(identity));

        TokenCloneable token = TokenCloneable(tokenFactory.createToken("T", "T", 18, address(this)));
        token.setIdentityRegistry(address(idRegistry));
        token.setTrustedIssuersRegistry(address(trustedIssuers));
        token.setClaimTopicsRegistry(address(topicsRegistry));

        assertTrue(identity.claimExists(1, issuer), "el claim firmado se almacena");
        assertFalse(token.isVerified(owner), "un issuer no autorizado para el topic nunca cuenta");
    }

    // ------------------------------------------------------------------
    // AF-03: el digest cubre el `uri` (uriHash)
    // ------------------------------------------------------------------

    /// @notice AF-03: una firma emitida para un `uri` NO sirve para dar de alta otro distinto.
    /// Mismo criterio que `data`: el issuer fija la referencia documental off-chain.
    function test_AF03_addClaim_uri_alterado_revierte() public {
        bytes memory data = abi.encode("KYC", owner);
        // El issuer firma la referencia documental "https://kyc.a/1".
        bytes memory sig = _sign(ISSUER_PK, 1, 1, data, EXPIRES_AT, "https://kyc.a/1");

        // El titular intenta publicar otra distinta reutilizando la firma.
        vm.prank(owner);
        vm.expectRevert(bytes("Signature signer mismatch"));
        identity.addClaim(1, 1, issuer, sig, data, "https://kyc.a/2", EXPIRES_AT);

        assertFalse(identity.claimExists(1, issuer), "no debe persistir el claim con uri no firmado");
    }

    /// @notice AF-03: con el `uri` correcto (el firmado) el alta es correcta y se almacena tal cual.
    function test_AF03_addClaim_uri_correcto_ok() public {
        bytes memory data = abi.encode("KYC", owner);
        string memory uri = "https://kyc.example.com/claims/42";
        bytes memory sig = _sign(ISSUER_PK, 1, 1, data, EXPIRES_AT, uri);

        vm.prank(owner);
        identity.addClaim(1, 1, issuer, sig, data, uri, EXPIRES_AT);

        (,,,,, string memory returnedUri,,) = identity.getClaim(1, issuer);
        assertEq(returnedUri, uri, "el uri firmado se almacena");
        assertTrue(identity.claimExists(1, issuer));
    }

    /// @notice AF-03: el digest EIP-712 cambia si cambia el `uri` (binding explicito).
    function test_AF03_digest_cambia_con_el_uri() public {
        bytes memory data = abi.encode("KYC", owner);

        bytes32 digestA = SigUtils.claimDigest(address(identity), owner, 1, 1, data, EXPIRES_AT, 0, "uri-a");
        bytes32 digestB = SigUtils.claimDigest(address(identity), owner, 1, 1, data, EXPIRES_AT, 0, "uri-b");
        bytes32 digestEmpty = SigUtils.claimDigest(address(identity), owner, 1, 1, data, EXPIRES_AT, 0, "");

        assertTrue(digestA != digestB, "el uri debe cambiar el digest");
        assertTrue(digestA != digestEmpty, "uri vacio tambien cambia el digest");
        // Reproducibilidad: el mismo uri produce el mismo digest.
        assertEq(digestA, SigUtils.claimDigest(address(identity), owner, 1, 1, data, EXPIRES_AT, 0, "uri-a"));
    }
}
