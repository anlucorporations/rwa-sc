// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ICompliance} from "../src/ICompliance.sol";
import {MaxBalanceCompliance} from "../src/compliance/MaxBalanceCompliance.sol";
import {MaxHoldersCompliance} from "../src/compliance/MaxHoldersCompliance.sol";
import {TransferLockCompliance} from "../src/compliance/TransferLockCompliance.sol";
import {ComplianceAggregator} from "../src/compliance/ComplianceAggregator.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";
import {TokenCloneFactory} from "../src/TokenCloneFactory.sol";

/**
 * @dev Contrato cualquiera SIN `supportsInterface` (no implementa ERC-165).
 * Sirve para el caso "contrato sin interfaz" de RF-003.
 */
contract NoInterfaceContract {
    function doSomething() external pure returns (uint256) {
        return 42;
    }
}

/**
 * @dev Contrato que declara ERC-165 pero rechaza `type(ICompliance).interfaceId`.
 * Sirve para el caso "contrato con ERC-165 que no es ICompliance".
 */
contract WrongInterfaceContract {
    function supportsInterface(bytes4) external pure returns (bool) {
        return false;
    }
}

/**
 * @title RF003_ERC165Test
 * @notice Ciclo 4 — RF-003 (HB-04 / H-17): validación ERC-165 de módulos de compliance.
 *
 * Cubre:
 * - `type(ICompliance).interfaceId` = XOR de los 4 selectores propios (sin cambios al heredar IERC165).
 * - `supportsInterface` de los 3 módulos y del aggregator (ICompliance + IERC165).
 * - `TokenCloneable.addComplianceModule`: EOA, contrato sin interfaz, contrato con ERC-165 ajeno y
 *   `address(0)` revierten; módulo conforme se da de alta; duplicado revierte.
 * - `ComplianceAggregator.addModule` a traves de la ruta de produccion token -> aggregator (RF-012 /
 *   CU-16): el aggregator valida ERC-165 y el token conserva el rechazo de modulo cero.
 * - `addModuleThroughAggregator` sigue funcionando (CU-05).
 */
contract RF003_ERC165Test is Test {
    event ComplianceModuleAdded(address indexed module);

    ComplianceAggregator internal aggregator;
    TokenCloneable internal token;
    TokenCloneFactory internal tokenFactory;
    address internal admin;

    function setUp() public {
        admin = address(this);
        aggregator = new ComplianceAggregator(admin);
        tokenFactory = new TokenCloneFactory(admin);
        token = TokenCloneable(tokenFactory.createToken("RF003 Token", "RF3", 18, admin));
    }

    // ---------------------------------------------------------------------
    // interfaceId y supportsInterface
    // ---------------------------------------------------------------------

    function test_RF003_interfaceId_ICompliance_correcto() public pure {
        bytes4 expected = ICompliance.canTransfer.selector ^ ICompliance.transferred.selector
            ^ ICompliance.created.selector ^ ICompliance.destroyed.selector;

        assertEq(type(ICompliance).interfaceId, expected, "interfaceId = XOR de los 4 selectores propios");
        assertEq(type(IERC165).interfaceId, bytes4(0x01ffc9a7), "IERC165 estandar");
        assertTrue(type(ICompliance).interfaceId != bytes4(0), "interfaceId no nulo");
    }

    function test_RF003_supportsInterface_modulos_conformes() public {
        _assertConforme(address(new MaxBalanceCompliance(admin, 1000 ether)));
        _assertConforme(address(new MaxHoldersCompliance(admin, 10)));
        _assertConforme(address(new TransferLockCompliance(admin, 30 days)));
        _assertConforme(address(aggregator));
    }

    // ---------------------------------------------------------------------
    // TokenCloneable.addComplianceModule
    // ---------------------------------------------------------------------

    function test_RF003_addComplianceModule_valida_erc165_ok() public {
        MaxBalanceCompliance module = new MaxBalanceCompliance(admin, 1000 ether);

        vm.expectEmit(true, false, false, true, address(token));
        emit ComplianceModuleAdded(address(module));

        token.addComplianceModule(address(module));

        address[] memory modules = token.getComplianceModules();
        assertEq(modules.length, 1);
        assertEq(modules[0], address(module));
    }

    function test_RF003_addComplianceModule_revierte_eoa() public {
        address eoa = makeAddr("eoaModule");

        vm.expectRevert("Module does not implement ICompliance");
        token.addComplianceModule(eoa);

        assertEq(token.getComplianceModules().length, 0, "no debe registrar la EOA");
    }

    function test_RF003_addComplianceModule_revierte_contrato_sin_interfaz() public {
        NoInterfaceContract bad = new NoInterfaceContract();

        vm.expectRevert("Module does not implement ICompliance");
        token.addComplianceModule(address(bad));

        assertEq(token.getComplianceModules().length, 0);
    }

    function test_RF003_addComplianceModule_revierte_erc165_ajeno() public {
        WrongInterfaceContract wrong = new WrongInterfaceContract();

        vm.expectRevert("Module does not implement ICompliance");
        token.addComplianceModule(address(wrong));

        assertEq(token.getComplianceModules().length, 0);
    }

    function test_RF003_addComplianceModule_zero_revierte() public {
        vm.expectRevert("Invalid module address");
        token.addComplianceModule(address(0));
    }

    function test_RF003_addComplianceModule_no_escribe_si_invalido() public {
        vm.expectRevert("Module does not implement ICompliance");
        token.addComplianceModule(makeAddr("eoaModule"));

        assertEq(token.getComplianceModules().length, 0, "revert sin modificar el estado");

        // El estado sigue siendo utilizable: un modulo conforme si se registra.
        token.addComplianceModule(address(new MaxBalanceCompliance(admin, 1000 ether)));
        assertEq(token.getComplianceModules().length, 1);
    }

    function test_RF003_addComplianceModule_duplicado_revierte() public {
        MaxBalanceCompliance module = new MaxBalanceCompliance(admin, 1000 ether);
        token.addComplianceModule(address(module));

        vm.expectRevert("Module already added");
        token.addComplianceModule(address(module));

        assertEq(token.getComplianceModules().length, 1);
    }

    // ---------------------------------------------------------------------
    // ComplianceAggregator.addModule (ruta de produccion token -> aggregator, RF-012)
    // ---------------------------------------------------------------------

    function test_RF003_aggregator_addModule_valida_erc165_ok() public {
        MaxHoldersCompliance module = new MaxHoldersCompliance(admin, 10);

        token.addComplianceModule(address(aggregator));
        token.addModuleThroughAggregator(address(aggregator), address(module));

        assertEq(aggregator.getModuleCount(address(token)), 1);
        assertTrue(aggregator.isModuleActiveForToken(address(token), address(module)));
    }

    function test_RF003_aggregator_addModule_revierte_eoa() public {
        token.addComplianceModule(address(aggregator));

        vm.expectRevert("Module does not implement ICompliance");
        token.addModuleThroughAggregator(address(aggregator), makeAddr("eoaModule"));

        assertEq(aggregator.getModuleCount(address(token)), 0);
    }

    function test_RF003_aggregator_addModule_revierte_contrato_sin_interfaz() public {
        NoInterfaceContract bad = new NoInterfaceContract();

        token.addComplianceModule(address(aggregator));

        vm.expectRevert("Module does not implement ICompliance");
        token.addModuleThroughAggregator(address(aggregator), address(bad));

        assertEq(aggregator.getModuleCount(address(token)), 0);
    }

    function test_RF003_aggregator_addModule_zero_revierte() public {
        token.addComplianceModule(address(aggregator));

        vm.expectRevert("Invalid module address");
        token.addModuleThroughAggregator(address(aggregator), address(0));
    }

    // ---------------------------------------------------------------------
    // Integracion token <-> aggregator (CU-05)
    // ---------------------------------------------------------------------

    function test_RF003_addComplianceModule_agregador_conforme() public {
        token.addComplianceModule(address(aggregator));

        address[] memory modules = token.getComplianceModules();
        assertEq(modules.length, 1);
        assertEq(modules[0], address(aggregator));
    }

    function test_RF003_addModuleThroughAggregator_ok() public {
        token.addComplianceModule(address(aggregator));

        TransferLockCompliance module = new TransferLockCompliance(admin, 30 days);
        token.addModuleThroughAggregator(address(aggregator), address(module));

        assertEq(token.getAggregatorModuleCount(address(aggregator)), 1);
        assertTrue(token.isModuleActiveInAggregator(address(aggregator), address(module)));
        assertTrue(aggregator.isModuleActiveForToken(address(token), address(module)));
    }

    function test_RF003_addModuleThroughAggregator_revierte_modulo_no_conforme() public {
        token.addComplianceModule(address(aggregator));

        NoInterfaceContract bad = new NoInterfaceContract();

        vm.expectRevert("Module does not implement ICompliance");
        token.addModuleThroughAggregator(address(aggregator), address(bad));

        assertEq(token.getAggregatorModuleCount(address(aggregator)), 0);
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _assertConforme(address module) internal view {
        assertTrue(ICompliance(module).supportsInterface(type(ICompliance).interfaceId), "ICompliance soportada");
        assertTrue(ICompliance(module).supportsInterface(type(IERC165).interfaceId), "IERC165 soportada");
        assertFalse(ICompliance(module).supportsInterface(bytes4(0xffffffff)), "interfaz desconocida rechazada");
    }
}
