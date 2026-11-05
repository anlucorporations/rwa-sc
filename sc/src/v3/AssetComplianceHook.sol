// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAssetCompliance, IIdentityRegistryLight, IIdentityLight} from "./IAssetCompliance.sol";

/// @title AssetComplianceHook (B6)
/// @notice Verificación fail-closed por transferencia: el receptor debe estar registrado
///         en el `IdentityRegistry` y tener al menos un claim válido de cada topic requerido.
/// @dev Sin `IdentityRegistry` configurado, NADIE es elegible (fail-closed, cierra RF-011/012).
abstract contract AssetComplianceHook is IAssetCompliance {
    IIdentityRegistryLight public identityRegistry;
    uint256[] internal requiredTopics;

    error ReceiverNotVerified(address receiver, uint256 topic);
    error RegistryNotConfigured();

    event RequiredTopicsUpdated(uint256[] topics);

    function topics() external view returns (uint256[] memory) {
        return requiredTopics;
    }

    /// @notice ¿Es `account` elegible para recibir/tener el activo?
    function isEligible(address account) public view returns (bool) {
        if (account == address(0)) return false;
        if (address(identityRegistry) == address(0)) return false;
        if (!identityRegistry.isRegistered(account)) return false;

        address identity = identityRegistry.getIdentity(account);
        if (identity == address(0)) return false;

        for (uint256 i = 0; i < requiredTopics.length; i++) {
            uint256 topic = requiredTopics[i];
            address[] memory issuers = IIdentityLight(identity).getClaimIssuersForTopic(topic);
            bool ok = false;
            for (uint256 j = 0; j < issuers.length; j++) {
                if (IIdentityLight(identity).hasValidClaim(topic, issuers[j])) {
                    ok = true;
                    break;
                }
            }
            if (!ok) return false;
        }
        return true;
    }

    function _requireEligible(address account) internal view {
        if (address(identityRegistry) == address(0)) revert RegistryNotConfigured();
        for (uint256 i = 0; i < requiredTopics.length; i++) {
            if (!isEligible(account)) revert ReceiverNotVerified(account, requiredTopics[i]);
        }
    }

    function _setRequiredTopics(uint256[] memory topics_) internal {
        requiredTopics = topics_;
        emit RequiredTopicsUpdated(topics_);
    }
}
