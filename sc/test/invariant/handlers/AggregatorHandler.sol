// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ComplianceAggregator} from "../../../src/compliance/ComplianceAggregator.sol";
import {TokenCloneable} from "../../../src/TokenCloneable.sol";
import {BaseHandler} from "./BaseHandler.sol";

/**
 * @title AggregatorGhosts
 * @notice Modelo fantasma de los modulos activos por token y de las violaciones de aislamiento.
 */
contract AggregatorGhosts {
    mapping(address => mapping(address => bool)) public expectedActive;
    bool public crossTokenViolation;
    /// @dev Contador de acciones con exito (evidencia de que el handler ejercita caminos reales).
    mapping(bytes32 => uint256) public successCount;

    function markActive(address token, address module, bool value) external {
        expectedActive[token][module] = value;
    }

    function markCrossTokenViolation() external {
        crossTokenViolation = true;
    }

    function record(bytes32 action) external {
        successCount[action]++;
    }
}

/**
 * @title AggregatorHandler
 * @notice Handler con estado para `ComplianceAggregator` (RF-009 / Fase 4, CU-16).
 *
 * Acciones: alta y baja de modulos por la via de produccion (token -> aggregator) y ataques de
 * aislamiento (un token intentando administrar los modulos de otro, o el owner global intentando
 * administrar los de un token). Los ataques que tuvieran exito se registran como violacion.
 */
contract AggregatorHandler is BaseHandler {
    struct Config {
        ComplianceAggregator aggregator;
        address globalOwner;
        AggregatorGhosts ghosts;
        address[] tokens;
        address[] modules;
    }

    ComplianceAggregator private aggregator;
    address private globalOwner;
    AggregatorGhosts private ghosts;
    address[] private tokens;
    address[] private modules;

    constructor(Config memory config) {
        aggregator = config.aggregator;
        globalOwner = config.globalOwner;
        ghosts = config.ghosts;
        tokens = config.tokens;
        modules = config.modules;
    }

    // ============ Alta/baja por la via de produccion ============

    function addModule(uint256 tokenSeed, uint256 moduleSeed) external {
        address token = tokens[tokenSeed % tokens.length];
        address module = modules[moduleSeed % modules.length];
        bool ok = _call(token, abi.encodeCall(TokenCloneable.addModuleThroughAggregator, (address(aggregator), module)));
        if (ok) {
            ghosts.markActive(token, module, true);
            ghosts.record("addModule");
        }
    }

    function removeModule(uint256 tokenSeed, uint256 moduleSeed) external {
        address token = tokens[tokenSeed % tokens.length];
        address module = modules[moduleSeed % modules.length];
        bool ok =
            _call(token, abi.encodeCall(TokenCloneable.removeModuleThroughAggregator, (address(aggregator), module)));
        if (ok) {
            ghosts.markActive(token, module, false);
            ghosts.record("removeModule");
        }
    }

    // ============ Ataques de aislamiento ============

    /// @dev Un token intenta administrar los modulos de otro token directamente en el aggregator.
    function crossTokenAddModule(uint256 victimSeed, uint256 callerTokenSeed, uint256 moduleSeed) external {
        address victim = tokens[victimSeed % tokens.length];
        address caller = tokens[callerTokenSeed % tokens.length];
        if (caller == victim) {
            return;
        }
        address module = modules[moduleSeed % modules.length];
        vm.prank(caller);
        (bool ok,) = address(aggregator).call(abi.encodeCall(ComplianceAggregator.addModule, (victim, module)));
        if (ok) {
            ghosts.markCrossTokenViolation();
        }
    }

    function crossTokenRemoveModule(uint256 victimSeed, uint256 callerTokenSeed, uint256 moduleSeed) external {
        address victim = tokens[victimSeed % tokens.length];
        address caller = tokens[callerTokenSeed % tokens.length];
        if (caller == victim) {
            return;
        }
        address module = modules[moduleSeed % modules.length];
        vm.prank(caller);
        (bool ok,) = address(aggregator).call(abi.encodeCall(ComplianceAggregator.removeModule, (victim, module)));
        if (ok) {
            ghosts.markCrossTokenViolation();
        }
    }

    /// @dev El owner global del aggregator intenta administrar los modulos de un token ajeno.
    function globalOwnerAddModule(uint256 victimSeed, uint256 moduleSeed) external {
        address victim = tokens[victimSeed % tokens.length];
        address module = modules[moduleSeed % modules.length];
        vm.prank(globalOwner);
        (bool ok,) = address(aggregator).call(abi.encodeCall(ComplianceAggregator.addModule, (victim, module)));
        if (ok) {
            ghosts.markCrossTokenViolation();
        }
    }

    function globalOwnerRemoveModule(uint256 victimSeed, uint256 moduleSeed) external {
        address victim = tokens[victimSeed % tokens.length];
        address module = modules[moduleSeed % modules.length];
        vm.prank(globalOwner);
        (bool ok,) = address(aggregator).call(abi.encodeCall(ComplianceAggregator.removeModule, (victim, module)));
        if (ok) {
            ghosts.markCrossTokenViolation();
        }
    }
}
