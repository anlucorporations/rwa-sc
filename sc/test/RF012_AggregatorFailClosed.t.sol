// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ICompliance} from "../src/ICompliance.sol";
import {ComplianceAggregator} from "../src/compliance/ComplianceAggregator.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";
import {IdentityCloneable} from "../src/IdentityCloneable.sol";
import {TokenCloneFactory} from "../src/TokenCloneFactory.sol";
import {IdentityCloneFactory} from "../src/IdentityCloneFactory.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";
import {ClaimTopicsRegistry} from "../src/ClaimTopicsRegistry.sol";
import {SigUtils} from "./helpers/SigUtils.sol";

/// @dev Modulo de compliance que siempre aprueba; conforme a ERC-165 (RF-003).
contract AlwaysApproveCompliance is ICompliance {
    function canTransfer(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function transferred(address, address, uint256) external {}

    function created(address, uint256) external {}

    function destroyed(address, uint256) external {}

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ICompliance).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}

/// @dev Modulo de compliance que siempre rechaza; conforme a ERC-165 (RF-003).
contract AlwaysRejectCompliance is ICompliance {
    function canTransfer(address, address, uint256) external pure returns (bool) {
        return false;
    }

    function transferred(address, address, uint256) external {}

    function created(address, uint256) external {}

    function destroyed(address, uint256) external {}

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ICompliance).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}

/**
 * @title RF012_AggregatorFailClosedTest
 * @notice Ciclo 7 — RF-012 (CU-16): `ComplianceAggregator` fail-closed y administracion de modulos
 * **solo por el propio token**.
 *
 * Criterios cubiertos:
 * - Un token con el aggregator dado de alta pero sin modulos no puede transferir (fail-closed).
 * - Un token no registrado en el aggregator devuelve `false`.
 * - El admin/compliance del token administra modulos por la ruta de produccion (token -> aggregator).
 * - El owner global del aggregator no puede administrar los modulos de un token ajeno
 *   ("Only token admin can call").
 * - El aggregator exige que **todos** los modulos aprueben.
 * - Registro automatico del token al anadir el primer modulo (evento `TokenRegistered`, D-023).
 */
contract RF012_AggregatorFailClosedTest is Test {
    event TokenRegistered(address indexed token);

    uint256 internal constant ISSUER_PK = 0xB0B;
    uint256 internal constant KYC_TOPIC = 1;
    /// @dev D-038: `expiresAt == 0` = sin caducidad.
    uint256 internal constant EXPIRES_AT = 0;

    address internal admin = address(this);
    address internal aggregatorOwner;
    address internal issuer;
    address internal user1;
    address internal user2;

    TokenCloneFactory internal tokenFactory;
    IdentityCloneFactory internal identityFactory;
    IdentityRegistry internal identityRegistry;
    TrustedIssuersRegistry internal trustedIssuersRegistry;
    ClaimTopicsRegistry internal claimTopicsRegistry;

    TokenCloneable internal token;
    ComplianceAggregator internal aggregator;

    function setUp() public {
        aggregatorOwner = makeAddr("aggregatorOwner");
        issuer = vm.addr(ISSUER_PK);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // El owner global del aggregator es una cuenta SIN rol en el token.
        aggregator = new ComplianceAggregator(aggregatorOwner);

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

        token = TokenCloneable(tokenFactory.createToken("RF012 Token", "RF12", 18, admin));
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

    /// @dev Ruta de produccion: el aggregator se da de alta como modulo de compliance del token.
    function _attachAggregator() internal {
        token.addComplianceModule(address(aggregator));
    }

    /// @dev Ruta de produccion: el token (con COMPLIANCE_ROLE) anade el modulo al aggregator.
    function _addModuleViaToken(address module) internal {
        token.addModuleThroughAggregator(address(aggregator), module);
    }

    // ================= CU-16: criterios =================

    /// @notice Criterio 1: token con el aggregator dado de alta pero SIN modulos -> fail-closed.
    function test_RF012_aggregator_sin_modulos_revierte_transfer() public {
        // El saldo se acuna antes de dar de alta el aggregator (con compliance vacia, el token permite).
        token.mint(user1, 100 ether);

        _attachAggregator();
        assertEq(aggregator.getModuleCount(address(token)), 0, "sin modulos");
        assertFalse(aggregator.isTokenRegistered(address(token)), "aun no registrado");

        // La consulta que hace el token devuelve false.
        vm.prank(address(token));
        assertFalse(aggregator.canTransfer(user1, user2, 50 ether), "canTransfer debe ser false sin modulos");

        // Y la transferencia revierte por la comprobacion de compliance del token.
        vm.prank(user1);
        vm.expectRevert("Transfer not compliant");
        token.transfer(user2, 50 ether);
    }

    /// @notice Criterio 2: consulta para un token no registrado -> false.
    function test_RF012_aggregator_token_no_registrado_false() public {
        assertFalse(aggregator.isTokenRegistered(address(token)));

        vm.prank(address(token));
        assertFalse(aggregator.canTransfer(user1, user2, 1 ether), "token no registrado debe dar false");
    }

    /// @notice Criterio 3: el admin/compliance del token anade un modulo por la ruta del token.
    function test_RF012_aggregator_admin_del_token_ok() public {
        _attachAggregator();

        AlwaysApproveCompliance module = new AlwaysApproveCompliance();
        _addModuleViaToken(address(module));

        assertTrue(
            aggregator.isModuleActiveForToken(address(token), address(module)),
            "isModuleActiveForToken(T, module) debe ser true"
        );
        assertEq(aggregator.getModuleCount(address(token)), 1, "getModuleCount(T) == 1");
    }

    /// @notice Criterio 4: el owner global del aggregator no administra modulos de un token ajeno.
    function test_RF012_aggregator_owner_global_token_ajeno_revierte() public {
        _attachAggregator();

        AlwaysApproveCompliance module = new AlwaysApproveCompliance();

        vm.prank(aggregatorOwner);
        vm.expectRevert("Only token admin can call");
        aggregator.addModule(address(token), address(module));

        assertEq(aggregator.getModuleCount(address(token)), 0, "el owner global no registra nada");
    }

    /// @notice Criterio 5: todos los modulos deben aprobar; basta uno que rechace para devolver false.
    function test_RF012_aggregator_modulos_todos_true_ok() public {
        _attachAggregator();

        AlwaysApproveCompliance approveA = new AlwaysApproveCompliance();
        AlwaysApproveCompliance approveB = new AlwaysApproveCompliance();
        _addModuleViaToken(address(approveA));
        _addModuleViaToken(address(approveB));

        vm.prank(address(token));
        assertTrue(aggregator.canTransfer(user1, user2, 1 ether), "con dos modulos que aprueban debe dar true");

        AlwaysRejectCompliance reject = new AlwaysRejectCompliance();
        _addModuleViaToken(address(reject));

        vm.prank(address(token));
        assertFalse(aggregator.canTransfer(user1, user2, 1 ether), "un modulo que rechaza invalida el conjunto");
    }

    /// @notice EARS: por defecto (sin modulos activos) el aggregator deniega, sin revertir.
    function test_RF012_aggregator_failclosed_por_defecto() public {
        _attachAggregator();

        vm.prank(address(token));
        bool allowed = aggregator.canTransfer(user1, user2, 1 ether);
        assertFalse(allowed, "fail-closed por defecto");

        // La propia funcion no revierte: es una view que devuelve false.
        assertFalse(aggregator.isTokenRegistered(address(token)));
    }

    /// @notice C-3 / H-19: un token no puede administrar los modulos de otro token ajeno.
    function test_RF012_aggregator_aislamiento_cross_token() public {
        TokenCloneable token2 = TokenCloneable(tokenFactory.createToken("RF012 Token 2", "RF12B", 18, admin));
        token2.setIdentityRegistry(address(identityRegistry));
        token2.setTrustedIssuersRegistry(address(trustedIssuersRegistry));
        token2.setClaimTopicsRegistry(address(claimTopicsRegistry));

        _attachAggregator();

        AlwaysApproveCompliance module = new AlwaysApproveCompliance();

        // `token` (token1) no puede registrar modulos para token2.
        vm.prank(address(token));
        vm.expectRevert("Only token admin can call");
        aggregator.addModule(address(token2), address(module));

        assertEq(aggregator.getModuleCount(address(token2)), 0, "token ajeno no queda alterado");
    }

    /// @notice D-023: al anadir el primer modulo el token se registra automaticamente.
    function test_RF012_aggregator_registro_automatico_token() public {
        _attachAggregator();
        assertFalse(aggregator.isTokenRegistered(address(token)));

        AlwaysApproveCompliance module = new AlwaysApproveCompliance();

        vm.expectEmit(true, false, false, true, address(aggregator));
        emit TokenRegistered(address(token));

        _addModuleViaToken(address(module));

        assertTrue(aggregator.isTokenRegistered(address(token)), "registro automatico al primer modulo");
        assertEq(aggregator.getTokenCount(), 1);
        address[] memory registered = aggregator.getTokens();
        assertEq(registered.length, 1);
        assertEq(registered[0], address(token));
    }

    /// @notice CU-16 EARS `test_RF012_retirar_ultimo_modulo_bloquea`: retirar el ultimo modulo activo
    /// devuelve el aggregator a fail-closed: `canTransfer` false y la transferencia revierte.
    function test_RF012_retirar_ultimo_modulo_bloquea() public {
        token.mint(user1, 100 ether);

        _attachAggregator();
        AlwaysApproveCompliance module = new AlwaysApproveCompliance();
        _addModuleViaToken(address(module));
        assertEq(aggregator.getModuleCount(address(token)), 1, "un modulo activo");

        vm.prank(address(token));
        assertTrue(aggregator.canTransfer(user1, user2, 1 ether), "con el modulo debe permitir");

        token.removeModuleThroughAggregator(address(aggregator), address(module));

        assertEq(aggregator.getModuleCount(address(token)), 0, "sin modulos activos");
        vm.prank(address(token));
        assertFalse(aggregator.canTransfer(user1, user2, 1 ether), "fail-closed tras retirar el ultimo modulo");

        vm.prank(user1);
        vm.expectRevert("Transfer not compliant");
        token.transfer(user2, 1 ether);
    }
}
