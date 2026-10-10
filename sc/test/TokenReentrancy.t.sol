// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";
import {IdentityCloneable} from "../src/IdentityCloneable.sol";
import {TokenCloneFactory} from "../src/TokenCloneFactory.sol";
import {IdentityCloneFactory} from "../src/IdentityCloneFactory.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";
import {ClaimTopicsRegistry} from "../src/ClaimTopicsRegistry.sol";
import {ComplianceAggregator} from "../src/compliance/ComplianceAggregator.sol";
import {ICompliance} from "../src/ICompliance.sol";
import {SigUtils} from "./helpers/SigUtils.sol";

/**
 * @title MaliciousComplianceModule
 * @notice Módulo de compliance malicioso para los tests de RF-002 (H-18).
 * `canTransfer` siempre aprueba; desde `transferred`/`created`/`destroyed` reentra, si está
 * armado, en el contrato y con el calldata configurados, propagando el revert tal cual. Sirve
 * para demostrar que el `ReentrancyGuard` del token/aggregator revierte la reentrada con
 * `ReentrancyGuardReentrantCall`. También cuenta las llamadas para verificar notificaciones.
 */
contract MaliciousComplianceModule is ICompliance {
    address public attackTarget;
    bytes public attackCallData;
    bool public armed;

    uint256 public transferredCount;
    uint256 public createdCount;
    uint256 public destroyedCount;

    function arm(address target, bytes calldata callData) external {
        attackTarget = target;
        attackCallData = callData;
        armed = true;
    }

    function disarm() external {
        armed = false;
    }

    function canTransfer(address, address, uint256) external view returns (bool) {
        return true;
    }

    /// @dev RF-003: el token valida ERC-165 al dar de alta el modulo.
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ICompliance).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function transferred(address, address, uint256) external {
        transferredCount++;
        _attack();
    }

    function created(address, uint256) external {
        createdCount++;
        _attack();
    }

    function destroyed(address, uint256) external {
        destroyedCount++;
        _attack();
    }

    function _attack() internal {
        if (!armed) return;
        (bool ok, bytes memory ret) = attackTarget.call(attackCallData);
        if (!ok) {
            assembly {
                revert(add(ret, 0x20), mload(ret))
            }
        }
    }
}

/// @notice Módulo que siempre rechaza; demuestra que `forcedTransfer` sigue saltándose la
/// compliance mientras que `transfer`/`transferFrom` quedan sujetos a ella.
contract RejectingComplianceModule is ICompliance {
    function canTransfer(address, address, uint256) external view returns (bool) {
        return false;
    }

    /// @dev RF-003: conforme a ERC-165 para poder registrarse como modulo.
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ICompliance).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function transferred(address, address, uint256) external {}

    function created(address, uint256) external {}

    function destroyed(address, uint256) external {}
}

/**
 * @title TokenReentrancyTest
 * @notice RF-002 (Ciclo 3): retirada de `bypassCompliance`, ruta explícita `_forcedUpdate` y
 * anti-reentrancia (`ReentrancyGuard`) en el token y en el `ComplianceAggregator`.
 */
contract TokenReentrancyTest is Test {
    TokenCloneable public token;
    TokenCloneFactory public tokenFactory;
    IdentityCloneFactory public identityFactory;
    IdentityRegistry public identityRegistry;
    TrustedIssuersRegistry public trustedIssuersRegistry;
    ClaimTopicsRegistry public claimTopicsRegistry;

    MaliciousComplianceModule public maliciousModule;

    address public admin;
    address public issuer;
    address public user1;
    address public user2;

    uint256 internal constant ISSUER_PK = 0xB0B;
    uint256 internal constant EXPIRES_AT = 2_000_000_000;
    uint256 internal constant KYC_TOPIC = 1;

    function setUp() public {
        admin = address(this);
        issuer = vm.addr(ISSUER_PK);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        tokenFactory = new TokenCloneFactory(admin);
        identityFactory = new IdentityCloneFactory(admin);

        token = TokenCloneable(tokenFactory.createToken("Security Token", "SEC", 18, admin));

        identityRegistry = new IdentityRegistry(admin);
        trustedIssuersRegistry = new TrustedIssuersRegistry(admin);
        claimTopicsRegistry = new ClaimTopicsRegistry(admin);

        token.setIdentityRegistry(address(identityRegistry));
        token.setTrustedIssuersRegistry(address(trustedIssuersRegistry));
        token.setClaimTopicsRegistry(address(claimTopicsRegistry));

        uint256[] memory topics = new uint256[](1);
        topics[0] = KYC_TOPIC;
        trustedIssuersRegistry.addTrustedIssuer(issuer, topics);
        claimTopicsRegistry.addClaimTopic(KYC_TOPIC);

        _registerVerified(user1);
        _registerVerified(user2);

        maliciousModule = new MaliciousComplianceModule();
        token.addComplianceModule(address(maliciousModule));

        // RF-004: los topes y la whitelist son fail-closed por defecto. Esta suite prueba la
        // reentrancia, no los topes (cubiertos en TokenLimits.t.sol), asi que se autorizan los
        // destinos usados y se levantan los topes para que el guard de reentrancia sea lo que revierte.
        token.setAuthorizedDestination(user2, true);
        token.setMaxBurnPerTx(type(uint256).max);
        token.setMaxForcedPerTx(type(uint256).max);
    }

    function _registerVerified(address wallet) internal {
        IdentityCloneable identity = IdentityCloneable(identityFactory.createIdentity(admin));
        identityRegistry.registerIdentity(wallet, address(identity));

        bytes memory data = abi.encode("KYC", address(identity));
        bytes memory signature = SigUtils.signClaim(ISSUER_PK, address(identity), admin, KYC_TOPIC, 1, data, EXPIRES_AT);
        identity.addClaim(KYC_TOPIC, 1, issuer, signature, data, "", EXPIRES_AT);
    }

    /// @dev Selector del error de OpenZeppelin que deben devolver las reentradas.
    function _reentrancyError() internal pure returns (bytes4) {
        return ReentrancyGuard.ReentrancyGuardReentrantCall.selector;
    }

    function _armOn(address target, bytes memory callData) internal {
        maliciousModule.arm(target, callData);
    }

    // ===================== Reentrancia en el token =====================

    /// @notice Un módulo malicioso que reentra en `transfer` desde `transferred` revierte.
    function test_RF002_reentrancy_transfer_revierte() public {
        token.mint(user1, 100 ether);
        _armOn(address(token), abi.encodeWithSignature("transfer(address,uint256)", user2, 1 ether));

        vm.prank(user1);
        vm.expectRevert(_reentrancyError());
        token.transfer(user2, 1 ether);
    }

    /// @notice Un módulo malicioso que reentra en `transferFrom` desde `transferred` revierte.
    function test_RF002_reentrancy_transferFrom_revierte() public {
        token.mint(user1, 100 ether);
        vm.prank(user1);
        token.approve(user2, 10 ether);
        _armOn(address(token), abi.encodeWithSignature("transferFrom(address,address,uint256)", user1, user2, 1 ether));

        vm.prank(user2);
        vm.expectRevert(_reentrancyError());
        token.transferFrom(user1, user2, 1 ether);
    }

    /// @notice La reentrada desde el callback `created` de `mint` revierte.
    function test_RF002_reentrancy_mint_revierte() public {
        _armOn(address(token), abi.encodeWithSignature("transfer(address,uint256)", user2, 1 ether));

        vm.expectRevert(_reentrancyError());
        token.mint(user1, 100 ether);
    }

    /// @notice La reentrada desde el callback `destroyed` de `burn` revierte.
    function test_RF002_reentrancy_burn_revierte() public {
        token.mint(user1, 100 ether);
        _armOn(address(token), abi.encodeWithSignature("transfer(address,uint256)", user2, 1 ether));

        vm.expectRevert(_reentrancyError());
        token.burn(user1, 10 ether);
    }

    /// @notice La reentrada desde el callback `transferred` de `forcedTransfer` revierte.
    function test_RF002_reentrancy_forcedTransfer_revierte() public {
        token.mint(user1, 100 ether);
        _armOn(address(token), abi.encodeWithSignature("transfer(address,uint256)", user2, 1 ether));

        vm.expectRevert(_reentrancyError());
        token.forcedTransfer(user1, user2, 10 ether);
    }

    /// @notice Control positivo: sin ataque, el guard no bloquea y se libera entre llamadas.
    function test_RF002_reentrancy_transfer_ok_sin_ataque() public {
        token.mint(user1, 100 ether);

        vm.prank(user1);
        assertTrue(token.transfer(user2, 10 ether));

        // El guard quedó libre: una segunda transferencia vuelve a funcionar.
        vm.prank(user1);
        assertTrue(token.transfer(user2, 10 ether));

        assertEq(token.balanceOf(user2), 20 ether);
    }

    // ===================== Reentrancia en el aggregator =====================

    /// @notice Un módulo del aggregator que reentra desde `transferred` revierte por el guard del aggregator.
    function test_RF002_reentrancy_aggregator_transferred_revierte() public {
        ComplianceAggregator aggregator = new ComplianceAggregator(admin);
        MaliciousComplianceModule aggregatorModule = new MaliciousComplianceModule();

        // RF-012: el aggregator solo admite altas del propio token, asi que se da de alta como
        // modulo de compliance del token y se anade el modulo por la ruta de produccion.
        token.addComplianceModule(address(aggregator));
        token.addModuleThroughAggregator(address(aggregator), address(aggregatorModule));

        token.mint(user1, 100 ether);

        aggregatorModule.arm(address(aggregator), abi.encodeCall(ComplianceAggregator.created, (user1, 1 ether)));

        vm.prank(user1);
        vm.expectRevert(_reentrancyError());
        token.transfer(user2, 1 ether);
    }

    /// @notice Un módulo del aggregator que reentra desde `created` revierte por el guard del aggregator.
    function test_RF002_reentrancy_aggregator_created_revierte() public {
        ComplianceAggregator aggregator = new ComplianceAggregator(admin);
        MaliciousComplianceModule aggregatorModule = new MaliciousComplianceModule();

        // RF-012: alta por la ruta de produccion (token -> aggregator).
        token.addComplianceModule(address(aggregator));
        token.addModuleThroughAggregator(address(aggregator), address(aggregatorModule));

        aggregatorModule.arm(address(aggregator), abi.encodeCall(ComplianceAggregator.destroyed, (user1, 1 ether)));

        vm.expectRevert(_reentrancyError());
        token.mint(user1, 100 ether);
    }

    // ===================== RF-002: semántica funcional =====================

    /// @notice `forcedTransfer` sigue funcionando para el agente y sigue saltándose `canTransfer`,
    /// mientras que la transferencia normal queda sujeta a compliance.
    function test_RF002_forcedTransfer_agente_ok() public {
        token.mint(user1, 100 ether);

        RejectingComplianceModule rejecting = new RejectingComplianceModule();
        token.addComplianceModule(address(rejecting));

        // La transferencia normal queda sujeta a compliance (el módulo rechaza)...
        vm.prank(user1);
        vm.expectRevert("Transfer not compliant");
        token.transfer(user2, 1 ether);

        // ...pero `forcedTransfer` del agente sigue funcionando sin consultar `canTransfer`.
        token.forcedTransfer(user1, user2, 40 ether);

        assertEq(token.balanceOf(user1), 60 ether);
        assertEq(token.balanceOf(user2), 40 ether);
    }

    /// @notice La transferencia normal sigue sujeta a compliance.
    function test_RF002_transfer_normal_sujeta_a_compliance_revierte() public {
        token.mint(user1, 100 ether);

        RejectingComplianceModule rejecting = new RejectingComplianceModule();
        token.addComplianceModule(address(rejecting));

        vm.prank(user1);
        vm.expectRevert("Transfer not compliant");
        token.transfer(user2, 1 ether);
    }

    /// @notice Camino feliz de la transferencia normal con compliance satisfecha.
    function test_RF002_transfer_normal_camino_feliz() public {
        token.mint(user1, 100 ether);

        vm.prank(user1);
        assertTrue(token.transfer(user2, 10 ether));

        assertEq(token.balanceOf(user1), 90 ether);
        assertEq(token.balanceOf(user2), 10 ether);
    }

    /// @notice `forcedTransfer` sigue restringido a `AGENT_ROLE`.
    function test_RF002_forcedTransfer_only_agent_revierte() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, token.AGENT_ROLE())
        );
        token.forcedTransfer(user1, user2, 1 ether);
        vm.stopPrank();
    }

    /// @notice `forcedTransfer(address(0), ...)` ya no puede acuñar por la ruta forzada (CU-04 A4.6).
    function test_RF002_forcedTransfer_from_cero_revierte() public {
        vm.expectRevert("Invalid from address");
        token.forcedTransfer(address(0), user2, 1 ether);

        assertEq(token.totalSupply(), 0);
        assertEq(token.balanceOf(user2), 0);
    }

    /// @notice `forcedTransfer` sigue exigiendo destino verificado.
    function test_RF002_forcedTransfer_destino_no_verificado_revierte() public {
        token.mint(user1, 100 ether);
        address unverified = makeAddr("unverified");

        // RF-004: hay que autorizar el destino para poder alcanzar la comprobacion de identidad.
        token.setAuthorizedDestination(unverified, true);

        vm.expectRevert("Recipient not verified");
        token.forcedTransfer(user1, unverified, 1 ether);
    }

    /// @notice `forcedTransfer` sigue notificando `transferred` exactamente una vez a los módulos.
    function test_RF002_forcedTransfer_notifica_modulos_una_vez() public {
        token.mint(user1, 100 ether);
        assertEq(maliciousModule.createdCount(), 1);
        assertEq(maliciousModule.transferredCount(), 0);

        token.forcedTransfer(user1, user2, 10 ether);

        assertEq(maliciousModule.transferredCount(), 1);
        assertEq(maliciousModule.createdCount(), 1);
    }

    // ===================== RF-002: gas =====================

    /// @notice Mide el gas marginal de una transferencia estándar con el guard caliente
    /// (segunda transferencia del mismo test) y con el guard frío (primera). El valor queda
    /// registrado en el log y en `.gas-snapshot` para comparar antes/después de RF-002.
    function test_RF002_gas_transfer_estandar() public {
        token.mint(user1, 100 ether);

        // Primera transferencia: el guard pasa de 0 (slot del clon) a ENTERED → coste frío.
        uint256 gasBefore = gasleft();
        vm.prank(user1);
        token.transfer(user2, 1 ether);
        uint256 coldTransferGas = gasBefore - gasleft();

        // Segunda transferencia: el guard ya está en NOT_ENTERED → coste caliente.
        gasBefore = gasleft();
        vm.prank(user1);
        token.transfer(user2, 1 ether);
        uint256 warmTransferGas = gasBefore - gasleft();

        console.log("Transferencia estandar (guard frio) gas:", coldTransferGas);
        console.log("Transferencia estandar (guard caliente) gas:", warmTransferGas);
        assertGt(coldTransferGas, warmTransferGas);
    }

    // ===================== RF-002: storage layout =====================

    /// @notice El artefacto compilado de `TokenCloneable` no contiene `bypassCompliance`.
    /// El control positivo comprueba que el storage layout está presente en el artefacto.
    function test_RF002_storage_layout_sin_bypassCompliance() public {
        string memory artifact =
            vm.readFile(string.concat(vm.projectRoot(), "/out/TokenCloneable.sol/TokenCloneable.json"));

        assertTrue(_contains(artifact, "identityRegistry"), "storageLayout ausente en el artefacto");
        assertFalse(_contains(artifact, "bypassCompliance"), "bypassCompliance reaparecio en el storage layout");
    }

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length == 0) return true;
        if (n.length > h.length) return false;
        for (uint256 i = 0; i <= h.length - n.length; i++) {
            bool matched = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    matched = false;
                    break;
                }
            }
            if (matched) return true;
        }
        return false;
    }
}
