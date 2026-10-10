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
import {ComplianceAggregator} from "../src/compliance/ComplianceAggregator.sol";
import {MaxBalanceCompliance} from "../src/compliance/MaxBalanceCompliance.sol";
import {MaxHoldersCompliance} from "../src/compliance/MaxHoldersCompliance.sol";
import {AllowAllCompliance} from "./mocks/AllowAllCompliance.sol";
import {SigUtils} from "./helpers/SigUtils.sol";

/**
 * @title AuditoriaFinalAFTest
 * @notice Cierre de la Fase 4 (Pruebas): hallazgos de la auditoria adversarial final.
 *
 * Cubre:
 * - **AF-01 (ALTA)**: el alta de un modulo de compliance valida que un modulo de un solo token
 *   este **vinculado al token** (`tokenContract() == address(this)`); los modulos multi-token que
 *   no exponen `tokenContract()` (aggregator) quedan exentos. Ademas, un modulo mal configurado
 *   ya **no revierte** el camino de transferencia (lectura defensiva en los modulos): degrada a
 *   `false`/sin cambios y el token sigue siendo recuperable.
 * - **AF-02 (MEDIA)**: `mint` y `burn` exigen `whenNotPaused`; `mint` rechaza destinos congelados;
 *   `forcedTransfer` (recuperacion de emergencia) sigue operativo en pausa.
 * - **AF-05 (MEDIA)**: el token es **fail-closed sin modulos**: `canTransfer` devuelve `false` con
 *   `complianceModules.length == 0` y `transfer` revierte `"Transfer not compliant"`. Con un modulo
 *   permisivo (`AllowAllCompliance`) la transferencia vuelve a funcionar. `mint` y `forcedTransfer`
 *   no dependen de `canTransfer`.
 * - **AF-13 (BAJA)**: `removeModuleThroughAggregator` aplica la simetria del alta (aggregator
 *   registrado + modulo activo para este token antes de delegar).
 */
contract AuditoriaFinalAFTest is Test {
    TokenCloneable internal token;
    TokenCloneFactory internal tokenFactory;
    IdentityCloneFactory internal identityFactory;
    IdentityRegistry internal identityRegistry;
    TrustedIssuersRegistry internal trustedIssuersRegistry;
    ClaimTopicsRegistry internal claimTopicsRegistry;

    ComplianceAggregator internal aggregator;

    address internal admin;
    address internal issuer;
    address internal user1;
    address internal user2;

    uint256 internal constant ISSUER_PK = 0xB0B;
    uint256 internal constant KYC_TOPIC = 1;
    uint256 internal constant EXPIRES_AT = 2_000_000_000;
    uint256 internal constant MAX_BALANCE = 1000 ether;

    bytes4 internal constant ENFORCED_PAUSE = bytes4(keccak256("EnforcedPause()"));

    function setUp() public {
        admin = address(this);
        issuer = vm.addr(ISSUER_PK);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        tokenFactory = new TokenCloneFactory(admin);
        identityFactory = new IdentityCloneFactory(admin);

        token = TokenCloneable(tokenFactory.createToken("Audit Token", "AUD", 18, admin));

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

        aggregator = new ComplianceAggregator(admin);

        // RF-004: escenario permisivo para aislar los hallazgos de la suite.
        token.setAuthorizedDestination(user2, true);
        token.setMaxBurnPerTx(type(uint256).max);
        token.setMaxForcedPerTx(type(uint256).max);
    }

    function _registerVerified(address wallet) internal {
        IdentityCloneable identity = IdentityCloneable(identityFactory.createIdentity(admin));
        bytes memory data = abi.encode("KYC", address(identity));
        identity.addClaim(
            KYC_TOPIC,
            1,
            issuer,
            SigUtils.signClaim(ISSUER_PK, address(identity), admin, KYC_TOPIC, 1, data, EXPIRES_AT),
            data,
            "",
            EXPIRES_AT
        );
        identityRegistry.registerIdentity(wallet, address(identity));
    }

    // ================= AF-01: vinculacion del modulo al token =================

    /// @notice AF-01: un modulo de un solo token apuntando a OTRO token se rechaza en el alta.
    function test_AF01_addComplianceModule_rechaza_modulo_de_otro_token() public {
        address otherToken = makeAddr("otherToken");
        MaxBalanceCompliance module = new MaxBalanceCompliance(admin, MAX_BALANCE);
        module.setTokenContract(otherToken);

        vm.expectRevert("Module not linked to this token");
        token.addComplianceModule(address(module));

        assertEq(token.getComplianceModules().length, 0, "no debe registrar un modulo ajeno");
    }

    /// @notice AF-01: un modulo de un solo token sin `setTokenContract` (tokenContract == 0) se rechaza.
    function test_AF01_addComplianceModule_rechaza_modulo_sin_token_contrato() public {
        MaxBalanceCompliance module = new MaxBalanceCompliance(admin, MAX_BALANCE);
        assertEq(module.tokenContract(), address(0), "precondicion: tokenContract sin configurar");

        vm.expectRevert("Module not linked to this token");
        token.addComplianceModule(address(module));

        assertEq(token.getComplianceModules().length, 0);
    }

    /// @notice AF-01: el aggregator (multi-token, sin `tokenContract()`) queda exento y se acepta.
    function test_AF01_addComplianceModule_acepta_aggregator_sin_tokenContract() public {
        token.addComplianceModule(address(aggregator));

        address[] memory modules = token.getComplianceModules();
        assertEq(modules.length, 1);
        assertEq(modules[0], address(aggregator));
    }

    /// @notice AF-01: el alta equivalante del aggregator tambien exige vinculacion al token destinatario.
    function test_AF01_aggregator_addModule_rechaza_modulo_no_vinculado() public {
        token.addComplianceModule(address(aggregator));

        MaxBalanceCompliance module = new MaxBalanceCompliance(admin, MAX_BALANCE);
        module.setTokenContract(makeAddr("otherToken"));

        vm.expectRevert("Module not linked to this token");
        token.addModuleThroughAggregator(address(aggregator), address(module));

        assertEq(aggregator.getModuleCount(address(token)), 0);
    }

    /// @notice AF-01 (regresion): un modulo vinculado y despues mal configurado NO revierte con un
    /// `abi.decode` opaco; el token deniega de forma explicita y sigue siendo recuperable.
    function test_AF01_modulo_mal_configurado_no_revierte_de_forma_opaca() public {
        MaxBalanceCompliance module = new MaxBalanceCompliance(admin, MAX_BALANCE);
        module.setTokenContract(address(token));
        token.addComplianceModule(address(module));

        // El modulo estaba bien vinculado, pero se reapunta a una cuenta sin `balanceOf`.
        module.setTokenContract(makeAddr("eoaSinBalanceOf"));

        // `canTransfer` publico no revierte: devuelve false (fail-closed).
        assertFalse(token.canTransfer(user1, user2, 1 ether), "debe degradar a false sin revertir");

        // La operacion deniega con el mensaje explicito del token, no con un Panic de decodificacion.
        vm.expectRevert("Mint not compliant");
        token.mint(user1, 1 ether);

        // Recuperacion: se reapunta el modulo al token y la emision vuelve a funcionar.
        module.setTokenContract(address(token));
        token.mint(user1, 1 ether);
        assertEq(token.balanceOf(user1), 1 ether, "el token no queda inoperable de forma permanente");
    }

    // ================= AF-02: pausa y congelacion =================

    /// @notice AF-02: en pausa, `mint` revierte con `EnforcedPause`.
    function test_AF02_mint_en_pausa_revierte() public {
        token.pause();

        vm.expectRevert(ENFORCED_PAUSE);
        token.mint(user1, 1 ether);

        assertEq(token.balanceOf(user1), 0);
    }

    /// @notice AF-02: en pausa, `burn` revierte con `EnforcedPause`.
    function test_AF02_burn_en_pausa_revierte() public {
        token.mint(user1, 10 ether);
        token.pause();

        vm.expectRevert(ENFORCED_PAUSE);
        token.burn(user1, 1 ether);

        assertEq(token.balanceOf(user1), 10 ether);
    }

    /// @notice AF-02: `forcedTransfer` sigue operativo durante la pausa (recuperacion de emergencia).
    function test_AF02_forcedTransfer_en_pausa_funciona() public {
        token.mint(user1, 100 ether);
        token.pause();

        token.forcedTransfer(user1, user2, 40 ether);

        assertEq(token.balanceOf(user1), 60 ether);
        assertEq(token.balanceOf(user2), 40 ether);
    }

    /// @notice AF-02: `mint` a una cuenta congelada revierte (antes se permitia).
    function test_AF02_mint_a_cuenta_congelada_revierte() public {
        token.freezeAccount(user1);

        vm.expectRevert("Recipient frozen");
        token.mint(user1, 1 ether);

        assertEq(token.balanceOf(user1), 0);
    }

    /// @notice AF-02: `unpause` restaura `mint` y `burn`.
    function test_AF02_unpause_restaura_mint_y_burn() public {
        token.pause();
        token.unpause();

        token.mint(user1, 10 ether);
        assertEq(token.balanceOf(user1), 10 ether);

        token.burn(user1, 4 ether);
        assertEq(token.balanceOf(user1), 6 ether);
    }

    // ================= AF-05: token fail-closed sin modulos =================

    /// @notice AF-05: sin ningun modulo registrado, `canTransfer` devuelve `false` (fail-closed).
    /// Antes esta rama salia del bucle vacio y devolvia `true` ("0 modulos = permitir todo").
    function test_AF05_canTransfer_false_sin_modulos() public {
        assertEq(token.getComplianceModules().length, 0, "precondicion: token sin modulos");
        // Los dos wallets estan verificados y el token no esta pausado ni congelado; el unico
        // motivo del rechazo es la ausencia de politica de compliance.
        assertTrue(token.isVerified(user1));
        assertTrue(token.isVerified(user2));
        assertFalse(token.paused());
        assertFalse(token.isFrozen(user1));
        assertFalse(token.isFrozen(user2));

        assertFalse(token.canTransfer(user1, user2, 1 ether), "sin modulos => false");
    }

    /// @notice AF-05: sin modulos, `transfer` revierte con el mensaje explicito del token.
    /// `mint` (operacion privilegiada del agente) sigue operativo para poder fondear.
    function test_AF05_transfer_revierte_sin_modulos() public {
        token.mint(user1, 100 ether);

        vm.prank(user1);
        vm.expectRevert("Transfer not compliant");
        token.transfer(user2, 1 ether);

        assertEq(token.balanceOf(user1), 100 ether, "el saldo no cambia");
        assertEq(token.balanceOf(user2), 0);
    }

    /// @notice AF-05: con **al menos un** modulo permisivo la transferencia vuelve a funcionar,
    /// de modo que la regla fail-closed no bloquea un token correctamente configurado.
    function test_AF05_con_modulo_permisivo_transfiere() public {
        AllowAllCompliance permissive = new AllowAllCompliance();
        token.addComplianceModule(address(permissive));
        assertEq(token.getComplianceModules().length, 1);

        token.mint(user1, 100 ether);
        assertTrue(token.canTransfer(user1, user2, 10 ether), "con modulo => true");

        vm.prank(user1);
        assertTrue(token.transfer(user2, 10 ether));
        assertEq(token.balanceOf(user1), 90 ether);
        assertEq(token.balanceOf(user2), 10 ether);
    }

    /// @notice AF-05: retirar el ultimo modulo vuelve a bloquear las transferencias; registrar de
    /// nuevo un modulo conforme recupera la operativa (no hay bloqueo permanente).
    function test_AF05_retirar_ultimo_modulo_bloquea_y_registrar_recupera() public {
        AllowAllCompliance permissive = new AllowAllCompliance();
        token.addComplianceModule(address(permissive));

        token.mint(user1, 100 ether);
        vm.prank(user1);
        token.transfer(user2, 10 ether);
        assertEq(token.balanceOf(user2), 10 ether);

        // Retirada del ultimo modulo: fail-closed inmediato.
        token.removeComplianceModule(0);
        assertEq(token.getComplianceModules().length, 0);
        assertFalse(token.canTransfer(user1, user2, 1 ether));
        vm.prank(user1);
        vm.expectRevert("Transfer not compliant");
        token.transfer(user2, 1 ether);

        // Re-registrar un modulo conforme recupera la operativa.
        token.addComplianceModule(address(permissive));
        assertTrue(token.canTransfer(user1, user2, 1 ether));
        vm.prank(user1);
        token.transfer(user2, 1 ether);
        assertEq(token.balanceOf(user2), 11 ether);
    }

    /// @notice AF-05: `mint` y `forcedTransfer` **no** dependen del array de modulos (la emision y
    /// la recuperacion son operaciones privilegiadas del agente). Con 0 modulos siguen operativas.
    function test_AF05_mint_y_forcedTransfer_no_dependen_de_modulos() public {
        assertEq(token.getComplianceModules().length, 0);

        token.mint(user1, 100 ether);
        assertEq(token.balanceOf(user1), 100 ether);

        token.forcedTransfer(user1, user2, 40 ether);
        assertEq(token.balanceOf(user1), 60 ether);
        assertEq(token.balanceOf(user2), 40 ether);
    }

    // ================= AF-13: simetria de removeModuleThroughAggregator =================

    /// @notice AF-13: retirar un modulo inactivo revierte con un motivo claro en el token.
    function test_AF13_removeModuleThroughAggregator_rechaza_modulo_inactivo() public {
        token.addComplianceModule(address(aggregator));
        MaxBalanceCompliance module = new MaxBalanceCompliance(admin, MAX_BALANCE);
        module.setTokenContract(address(token));

        vm.expectRevert("Module not active for this token");
        token.removeModuleThroughAggregator(address(aggregator), address(module));
    }

    /// @notice AF-13: se exige que el aggregator sea modulo registrado del token (simetria con el alta).
    function test_AF13_removeModuleThroughAggregator_rechaza_aggregator_no_registrado() public {
        MaxBalanceCompliance module = new MaxBalanceCompliance(admin, MAX_BALANCE);
        module.setTokenContract(address(token));

        vm.expectRevert("Aggregator not added as compliance module");
        token.removeModuleThroughAggregator(address(aggregator), address(module));
    }

    /// @notice AF-13: camino feliz, la retirada de un modulo activo sigue funcionando.
    function test_AF13_removeModuleThroughAggregator_ok() public {
        token.addComplianceModule(address(aggregator));
        MaxBalanceCompliance module = new MaxBalanceCompliance(admin, MAX_BALANCE);
        module.setTokenContract(address(token));
        token.addModuleThroughAggregator(address(aggregator), address(module));
        assertEq(aggregator.getModuleCount(address(token)), 1);

        token.removeModuleThroughAggregator(address(aggregator), address(module));

        assertEq(aggregator.getModuleCount(address(token)), 0);
        assertFalse(aggregator.isModuleActiveForToken(address(token), address(module)));
    }

    /// @notice AF-13: retirar por la ruta del token un modulo que pertenece a otro token revierte.
    function test_AF13_removeModuleThroughAggregator_rechaza_modulo_de_otro_token() public {
        token.addComplianceModule(address(aggregator));

        // Otro token y su modulo vinculado se registran en el mismo aggregator.
        TokenCloneable token2 = TokenCloneable(tokenFactory.createToken("Other", "OTH", 18, admin));
        token2.setIdentityRegistry(address(identityRegistry));
        token2.setTrustedIssuersRegistry(address(trustedIssuersRegistry));
        token2.setClaimTopicsRegistry(address(claimTopicsRegistry));
        token2.addComplianceModule(address(aggregator));

        MaxBalanceCompliance module2 = new MaxBalanceCompliance(admin, MAX_BALANCE);
        module2.setTokenContract(address(token2));
        token2.addModuleThroughAggregator(address(aggregator), address(module2));

        // El token 1 no puede retirar el modulo del token 2.
        vm.expectRevert("Module not active for this token");
        token.removeModuleThroughAggregator(address(aggregator), address(module2));
    }
}
