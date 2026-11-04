// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title BarloToken (BRLT)
/// @notice Moneda de pago de la plataforma RWA v3 «Barlo Metaplace».
///         ERC-20 de 8 decimales, suministro acotado por `cap` y emisión por rol.
/// @dev Decisiones aplicadas (D-V3-02, Q2, Q4, H-26):
///      - 8 decimales (BRLT).
///      - `cap` inmutable = 100.000.000 BRLT por defecto.
///      - `maxMintPerTx` configurable por el admin (10.000 BRLT por defecto).
///      - mint/burn/pause con roles; sin mint libre ni auto-mint.
///      - pausa de emergencia que bloquea transferencias, mint y burn.
///      - No es un token RWA: es medio de pago de utilidad, sin valor real en v3.0.
///      - Gobernanza de emisión y pausa delegada a un multisig/timelock externo
///        (`GovernanceMultisig`), no al EOA del despliegue.
contract BarloToken is ERC20, ERC20Burnable, Pausable, AccessControl {
    // Nota: ERC20Permit no se usa en v3.0 porque OZ 5.5 lo exige con solc ^0.8.24 y el
    // proyecto fija 0.8.20 (RT-V3-02). Si se sube el compilador, se reevalúa en v3.1.
    /// @notice Rol autorizado a acuñar.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// @notice Rol autorizado a pausar/reanudar.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Decimales de BRLT (fijados por decisión de producto).
    uint8 private constant DECIMALS = 8;

    /// @notice Suministro máximo emitible (en unidades mínimas, 8 decimales).
    uint256 public immutable cap;

    /// @notice Máximo acuñable en una sola transacción (en unidades mínimas).
    uint256 public maxMintPerTx;

    event MaxMintPerTxUpdated(uint256 previous, uint256 current);
    event Minted(address indexed to, uint256 amount, address indexed operator);
    event Burned(address indexed from, uint256 amount, address indexed operator);

    error ZeroAddress();
    error ZeroAmount();
    error CapExceeded(uint256 requested, uint256 available);
    error MaxMintPerTxExceeded(uint256 amount, uint256 limit);
    error InvalidCap();
    error InvalidMaxMintPerTx();
    error TokenPaused();

    /// @param admin Dirección administradora (multisig/timelock en producción).
    /// @param cap_ Suministro máximo en unidades mínimas.
    /// @param maxMintPerTx_ Máximo por transacción en unidades mínimas.
    constructor(address admin, uint256 cap_, uint256 maxMintPerTx_)
        ERC20("BarloToken", "BRLT")
    {
        if (admin == address(0)) revert ZeroAddress();
        if (cap_ == 0) revert InvalidCap();
        if (maxMintPerTx_ == 0 || maxMintPerTx_ > cap_) revert InvalidMaxMintPerTx();

        cap = cap_;
        maxMintPerTx = maxMintPerTx_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
    }

    /// @notice Decimales de BRLT: 8.
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    /// @notice Acuña `amount` a `to`. Solo MINTER_ROLE; respeta pausa, cap y límite por tx.
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) returns (bool) {
        if (paused()) revert TokenPaused();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > maxMintPerTx) revert MaxMintPerTxExceeded(amount, maxMintPerTx);

        uint256 available = cap - totalSupply();
        if (amount > available) revert CapExceeded(amount, available);

        _mint(to, amount);
        emit Minted(to, amount, msg.sender);
        return true;
    }

    /// @notice Quema `amount` del llamador (titular). Bloqueado en pausa.
    function burn(uint256 amount) public override whenNotPaused {
        super.burn(amount);
        emit Burned(msg.sender, amount, msg.sender);
    }

    /// @notice Quema `amount` de `account` con allowance. Bloqueado en pausa.
    function burnFrom(address account, uint256 amount) public override whenNotPaused {
        super.burnFrom(account, amount);
        emit Burned(account, amount, msg.sender);
    }

    /// @notice Pausa el token (emergencia). Solo PAUSER_ROLE.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Reanuda el token. Solo PAUSER_ROLE.
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice Actualiza el límite de acuñación por transacción. Solo admin.
    function setMaxMintPerTx(uint256 newLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newLimit == 0 || newLimit > cap) revert InvalidMaxMintPerTx();
        emit MaxMintPerTxUpdated(maxMintPerTx, newLimit);
        maxMintPerTx = newLimit;
    }

    /// @dev Pausable no se aplica solo a ERC20 en OZ v5: se comprueba aquí.
    function _update(address from, address to, uint256 value) internal override {
        if (paused()) revert TokenPaused();
        super._update(from, to, value);
    }
}
