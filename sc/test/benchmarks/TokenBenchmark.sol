// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TokenBenchmark
 * @notice LÍNEA BASE DE GAS — NO es un doble funcional de `TokenCloneable`.
 *
 * Representa el coste de "despliegue completo + inicialización" que el clon EIP-1167
 * evita: ERC20 + AccessControl + Pausable + ReentrancyGuard con las mismas asignaciones
 * de roles que `TokenCloneable.initialize` (DEFAULT_ADMIN, AGENT, COMPLIANCE) y los
 * mismos valores de nombre/símbolo/decimales. El `ReentrancyGuard` se añadió en el
 * Ciclo 3 (RF-002) para que la comparación siga siendo equivalente: `TokenCloneable`
 * hereda el mismo guard stateless (ERC-7201) de OpenZeppelin v5.5.0. Solo existe para
 * medir gas en `test_GasSavings`; no se despliega en producción ni se usa como
 * sustituto en otros tests.
 */
contract TokenBenchmark is ERC20, AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    uint8 private immutable _benchmarkDecimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, address admin) ERC20(name_, symbol_) {
        require(admin != address(0), "Invalid admin address");

        _benchmarkDecimals = decimals_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AGENT_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);
    }

    function decimals() public view virtual override returns (uint8) {
        return _benchmarkDecimals;
    }
}
