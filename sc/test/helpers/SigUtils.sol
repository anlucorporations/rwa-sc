// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vm} from "forge-std/Vm.sol";

/**
 * @title SigUtils
 * @notice Utilidad de test para construir el digest EIP-712 de RF-001 y firmarlo.
 *
 * Reproduce de forma independiente el dominio `{name: "RWA-Identity", version: "1",
 * chainId, verifyingContract}` y el `CLAIM_TYPEHASH` de D-020, para que los tests
 * verifiquen el contrato y no una copia de su propia implementacion.
 *
 * Uso: `bytes memory sig = SigUtils.signClaim(pk, address(identity), walletOwner, topic, scheme, data, expiresAt);`
 */
library SigUtils {
    address internal constant VM_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
    Vm internal constant VM = Vm(VM_ADDRESS);

    bytes32 internal constant CLAIM_TYPEHASH =
        keccak256("Claim(address walletOwner,uint256 topic,uint256 scheme,bytes32 dataHash,uint256 expiresAt)");

    bytes32 internal constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 internal constant DOMAIN_NAME_HASH = keccak256(bytes("RWA-Identity"));
    bytes32 internal constant DOMAIN_VERSION_HASH = keccak256(bytes("1"));

    /// @notice Domain separator de D-020 para el `verifyingContract` y `chainId` actuales.
    function domainSeparator(address verifyingContract) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(DOMAIN_TYPEHASH, DOMAIN_NAME_HASH, DOMAIN_VERSION_HASH, block.chainid, verifyingContract)
            );
    }

    /// @notice `structHash` del Claim firmado.
    function claimStructHash(address walletOwner, uint256 topic, uint256 scheme, bytes memory data, uint256 expiresAt)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(CLAIM_TYPEHASH, walletOwner, topic, scheme, keccak256(data), expiresAt));
    }

    /// @notice Digest final EIP-712 (`\x19\x01 || domainSeparator || structHash`).
    function claimDigest(
        address verifyingContract,
        address walletOwner,
        uint256 topic,
        uint256 scheme,
        bytes memory data,
        uint256 expiresAt
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator(verifyingContract),
                claimStructHash(walletOwner, topic, scheme, data, expiresAt)
            )
        );
    }

    /// @notice Firma EIP-712 y devuelve `r || s || v` (65 bytes) listo para `addClaim`.
    function signClaim(
        uint256 privateKey,
        address verifyingContract,
        address walletOwner,
        uint256 topic,
        uint256 scheme,
        bytes memory data,
        uint256 expiresAt
    ) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = VM.sign(
            privateKey, claimDigest(verifyingContract, walletOwner, topic, scheme, data, expiresAt)
        );
        return abi.encodePacked(r, s, v);
    }
}
