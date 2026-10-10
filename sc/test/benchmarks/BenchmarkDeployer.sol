// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TokenBenchmark} from "./TokenBenchmark.sol";
import {IdentityBenchmark, IdentityWithClaimBenchmark} from "./IdentityBenchmark.sol";
import {ClaimTopicsRegistry} from "../../src/ClaimTopicsRegistry.sol";

/**
 * @title BenchmarkDeployer
 * @notice Utilidades de medición de GAS para los tests de ahorro (H-03 / B-7).
 *
 * IMPORTANTE: `forge` reescribe las expresiones `new Contrato()` de contratos de
 * `src/` como una llamada al cheatcode `vm.deployCode`, que NO consume gas medido
 * por `gasleft()` (por eso los tests de gas originales desbordaban o pasaban con
 * cifras irreales). Aquí desplegamos la línea base con el opcode `CREATE` en
 * assembly, que sí consume gas real y es directamente comparable con el
 * `create` que usa EIP-1167 en `Clones.clone()`.
 *
 * Estas funciones solo existen para los tests de gas; no son contratos de producción.
 */
library BenchmarkDeployer {
    /**
     * @dev Despliega el benchmark de token (despliegue completo + inicialización
     *      equivalente a `TokenCloneable.initialize`).
     */
    function deployTokenBenchmark(string memory name_, string memory symbol_, uint8 decimals_, address admin)
        internal
        returns (address addr)
    {
        bytes memory code =
            abi.encodePacked(type(TokenBenchmark).creationCode, abi.encode(name_, symbol_, decimals_, admin));
        assembly {
            addr := create(0, add(code, 0x20), mload(code))
        }
        require(addr != address(0), "TokenBenchmark deploy failed");
    }

    /**
     * @dev Despliega el benchmark de identidad simple (despliegue completo + owner).
     */
    function deployIdentityBenchmark(address initialOwner) internal returns (address addr) {
        bytes memory code = abi.encodePacked(type(IdentityBenchmark).creationCode, abi.encode(initialOwner));
        assembly {
            addr := create(0, add(code, 0x20), mload(code))
        }
        require(addr != address(0), "IdentityBenchmark deploy failed");
    }

    /**
     * @dev Despliega el benchmark de identidad con claim inicial.
     */
    function deployIdentityWithClaimBenchmark(
        address initialOwner,
        uint256 topic,
        uint256 scheme,
        address issuer,
        bytes memory signature,
        bytes memory data,
        string memory uri,
        uint256 expiresAt
    ) internal returns (address addr) {
        bytes memory code = abi.encodePacked(
            type(IdentityWithClaimBenchmark).creationCode,
            abi.encode(initialOwner, topic, scheme, issuer, signature, data, uri, expiresAt)
        );
        assembly {
            addr := create(0, add(code, 0x20), mload(code))
        }
        require(addr != address(0), "IdentityWithClaimBenchmark deploy failed");
    }

    /**
     * @dev Despliega un `ClaimTopicsRegistry` no-upgradeable completo (línea base
     *      equivalente a `ClaimTopicsRegistryCloneFactory.createRegistry`).
     */
    function deployClaimTopicsRegistryBenchmark(address initialOwner) internal returns (address addr) {
        bytes memory code = abi.encodePacked(type(ClaimTopicsRegistry).creationCode, abi.encode(initialOwner));
        assembly {
            addr := create(0, add(code, 0x20), mload(code))
        }
        require(addr != address(0), "ClaimTopicsRegistry deploy failed");
    }
}
