// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ICompliance} from "../../src/ICompliance.sol";
import {ComplianceAggregator} from "../../src/compliance/ComplianceAggregator.sol";
import {TokenCloneable} from "../../src/TokenCloneable.sol";
import {TokenCloneFactory} from "../../src/TokenCloneFactory.sol";
import {AggregatorGhosts, AggregatorHandler} from "./handlers/AggregatorHandler.sol";

/// @dev Modulo de compliance que siempre aprueba; conforme a ERC-165 (RF-003).
contract ApproveComplianceModule is ICompliance {
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
contract RejectComplianceModule is ICompliance {
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
 * @title AggregatorInvariantsTest
 * @notice Invariantes con estado de `ComplianceAggregator` (RF-009 / Fase 4, CU-16).
 *
 * Cubre: fail-closed con 0 modulos; aislamiento por token (un token no administra los modulos de
 * otro, ni el owner global los de un token); y `getModuleCount`/`getModules`/`isModuleActiveForToken`
 * coherentes con el modelo fantasma de altas y bajas (incluida la baja del modulo del medio).
 */
contract AggregatorInvariantsTest is Test {
    ComplianceAggregator internal aggregator;
    TokenCloneable internal token1;
    TokenCloneable internal token2;

    AggregatorGhosts internal ghosts;
    AggregatorHandler internal handler;

    address internal admin = address(this);
    address internal aggregatorOwner;
    address internal probeFrom;
    address internal probeTo;
    address[] internal tokens;
    address[] internal modules;

    function setUp() public {
        aggregatorOwner = makeAddr("aggregatorOwner");
        probeFrom = makeAddr("probeFrom");
        probeTo = makeAddr("probeTo");

        aggregator = new ComplianceAggregator(aggregatorOwner);

        TokenCloneFactory tokenFactory = new TokenCloneFactory(admin);
        token1 = TokenCloneable(tokenFactory.createToken("Token 1", "TK1", 18, admin));
        token2 = TokenCloneable(tokenFactory.createToken("Token 2", "TK2", 18, admin));
        tokens.push(address(token1));
        tokens.push(address(token2));

        token1.addComplianceModule(address(aggregator));
        token2.addComplianceModule(address(aggregator));

        modules.push(address(new ApproveComplianceModule()));
        modules.push(address(new RejectComplianceModule()));
        modules.push(address(new ApproveComplianceModule()));

        ghosts = new AggregatorGhosts();
        handler = new AggregatorHandler(
            AggregatorHandler.Config({
                aggregator: aggregator, globalOwner: aggregatorOwner, ghosts: ghosts, tokens: tokens, modules: modules
            })
        );

        token1.grantRole(token1.COMPLIANCE_ROLE(), address(handler));
        token2.grantRole(token2.COMPLIANCE_ROLE(), address(handler));

        targetContract(address(handler));
    }

    // ============ Invariantes ============

    /// @notice Con 0 modulos activos para un token, `canTransfer` devuelve `false` (fail-closed);
    /// y para un emisor no registrado tambien.
    function invariant_aggregator_failclosed_sin_modulos() public {
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            if (aggregator.getModuleCount(token) == 0) {
                vm.prank(token);
                bool allowed = aggregator.canTransfer(probeFrom, probeTo, 1);
                assertFalse(allowed, "aggregator fail-open con 0 modulos");
            }
        }

        address unregisteredToken = makeAddr("unregisteredToken");
        vm.prank(unregisteredToken);
        assertFalse(aggregator.canTransfer(probeFrom, probeTo, 1), "aggregator permite token no registrado");
    }

    /// @notice Ningun token ha logrado administrar los modulos de otro (ni el owner global los de
    /// un token ajeno).
    function invariant_token_no_administra_modulos_ajenos() public view {
        assertFalse(ghosts.crossTokenViolation(), "un token administro modulos de otro token");
    }

    /// @notice `getModuleCount` coincide con los modulos activos y con `getModules`, sin
    /// duplicados, y ambos reflejan el modelo fantasma de altas/bajas.
    function invariant_getModuleCount_coincide_con_activos() public view {
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 count = aggregator.getModuleCount(token);
            address[] memory active = aggregator.getModules(token);

            assertEq(active.length, count, "getModules != getModuleCount");
            assertFalse(_hasDuplicate(active), "modulos duplicados en getModules");

            uint256 expectedCount = 0;
            for (uint256 j = 0; j < modules.length; j++) {
                if (ghosts.expectedActive(token, modules[j])) {
                    expectedCount++;
                }
                assertEq(
                    aggregator.isModuleActiveForToken(token, modules[j]),
                    ghosts.expectedActive(token, modules[j]),
                    "isModuleActiveForToken difiere del modelo fantasma"
                );
            }

            for (uint256 j = 0; j < active.length; j++) {
                assertTrue(
                    aggregator.isModuleActiveForToken(token, active[j]),
                    "modulo en getModules sin isModuleActiveForToken"
                );
            }

            assertEq(count, expectedCount, "getModuleCount difiere del numero de modulos activos esperados");
        }
    }

    /// @notice El array `tokens` y el mapping `_isTokenRegistered` nunca se desincronizan.
    function invariant_registro_de_tokens_consistente() public view {
        address[] memory registered = aggregator.getTokens();
        assertEq(registered.length, aggregator.getTokenCount(), "getTokenCount != tamano de getTokens");
        assertFalse(_hasDuplicate(registered), "tokens duplicados en el aggregator");

        for (uint256 i = 0; i < registered.length; i++) {
            assertTrue(aggregator.isTokenRegistered(registered[i]), "token del array no registrado en el mapping");
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            bool registeredModel = _arrayContains(registered, tokens[i]);
            assertEq(
                aggregator.isTokenRegistered(tokens[i]),
                registeredModel,
                "isTokenRegistered difiere de la pertenencia al array"
            );
        }
    }

    /// @notice Comprobacion del harness (test normal, no invariante): las acciones del handler
    /// alcanzan caminos de exito reales. Se hace como `test_` y no como `invariant_` porque una
    /// secuencia valida puede tener cero exitos sin violar ninguna propiedad.
    function test_handler_operativo() public {
        handler.addModule(0, 0);
        assertGt(ghosts.successCount("addModule"), 0, "addModule no tuvo exito");

        handler.removeModule(0, 0);
        assertGt(ghosts.successCount("removeModule"), 0, "removeModule no tuvo exito");
    }

    // ============ Helpers ============

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

    function _arrayContains(address[] memory arr, address value) internal pure returns (bool) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == value) {
                return true;
            }
        }
        return false;
    }
}
