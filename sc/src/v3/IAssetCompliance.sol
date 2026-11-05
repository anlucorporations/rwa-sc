// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Interfaz de elegibilidad que aplican los contratos de activo.
interface IAssetCompliance {
    function isEligible(address account) external view returns (bool);
}

/// @notice Vistas mínimas del IdentityRegistry de v2.
interface IIdentityRegistryLight {
    function isRegistered(address account) external view returns (bool);
    function getIdentity(address account) external view returns (address);
}

/// @notice Vistas mínimas del contrato Identity de v2 (claims).
interface IIdentityLight {
    function getClaimIssuersForTopic(uint256 topic) external view returns (address[] memory);
    function hasValidClaim(uint256 topic, address issuer) external view returns (bool);
}
