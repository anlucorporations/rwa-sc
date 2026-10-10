// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ICompliance} from "../../src/ICompliance.sol";

/**
 * @title AllowAllCompliance
 * @notice Modulo de compliance **permisivo** para tests (AF-05, Fase 4).
 *
 * Con AF-05 el token es fail-closed sin modulos: `canTransfer` devuelve `false` cuando
 * `complianceModules.length == 0`. Las suites que quieren seguir probando la semantica de
 * pausa/congelacion/identidad/limites de una transferencia (y no la ausencia de politica)
 * registran este modulo, que aprueba **siempre** y no mantiene estado.
 *
 * No expone `tokenContract()` a proposito: es un modulo multi-token (como el
 * `ComplianceAggregator`) y `addComplianceModule` lo considera exento de la vinculacion
 * `tokenContract() == token` de AF-01, de modo que una misma instancia sirve para cualquier
 * token de test.
 *
 * Implementa ERC-165 (`type(ICompliance).interfaceId`) para poder darse de alta (RF-003).
 */
contract AllowAllCompliance is ICompliance {
    /// @dev Aprueba cualquier transferencia, independientemente de origen, destino e importe.
    function canTransfer(address, address, uint256) external pure returns (bool) {
        return true;
    }

    /// @dev RF-003: declara la conformidad con `ICompliance` y `IERC165`.
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(ICompliance).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function transferred(address, address, uint256) external {}

    function created(address, uint256) external {}

    function destroyed(address, uint256) external {}
}
