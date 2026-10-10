// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vm} from "forge-std/Vm.sol";

/**
 * @title BaseHandler
 * @notice Utilidades compartidas por los handlers con estado de las pruebas de invariantes
 * (RF-009 / Fase 4).
 *
 * Un handler es un contrato SIN herencia de `Test`: asi su ABI solo contiene las acciones
 * acotadas que el fuzzer debe llamar (`targetContract`), y no los cientos de helpers de
 * forge-std. Los campos son `private`/`internal` para que no generen getters fuzzeables.
 */
abstract contract BaseHandler {
    /// @dev Direccion canonica del cheatcode `vm` de Foundry (no necesita importar Test).
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    /// @dev Acota `x` al intervalo cerrado `[min, max]` (implementacion propia de `bound`
    /// para no heredar `StdUtils`, que anadiria decenas de funciones al ABI del handler).
    function _bound(uint256 x, uint256 min, uint256 max) internal pure returns (uint256) {
        if (min >= max) {
            return min;
        }
        return min + (x % (max - min + 1));
    }

    /// @dev Llamada de bajo nivel que **nunca** propaga el revert: los handlers no deben
    /// revertir (si no, el fuzzer descarta la secuencia completa). El resultado se refleja en
    /// los ghosts del handler, no con `assert` (que `fail_on_revert = false` tambien tragaria).
    function _call(address target, bytes memory data) internal returns (bool ok) {
        (ok,) = target.call(data);
    }
}
