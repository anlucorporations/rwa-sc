// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IdentityBenchmark
 * @notice LÍNEA BASE DE GAS — NO es un doble funcional de `IdentityCloneable`.
 *
 * Réplica no-upgradeable del trabajo de despliegue + inicialización del clon:
 * fija el owner en el constructor (equivalente a `initialize`) y expone `addClaim`
 * con exactamente la misma estructura de almacenamiento y el mismo evento.
 * Sirve de base a `IdentityWithClaimBenchmark`. Solo existe para medir gas en
 * `testGasSavings`; no se despliega en producción.
 */
contract IdentityBenchmark is Ownable {
    struct Claim {
        uint256 topic;
        uint256 scheme;
        address issuer;
        bytes signature;
        bytes data;
        string uri;
        uint256 expiresAt;
    }

    // Mismos mapeos que IdentityCloneable (mismo coste de SSTORE al inicializar).
    mapping(uint256 => mapping(address => Claim)) internal claims;
    mapping(uint256 => address[]) internal topicIssuers;
    mapping(uint256 => mapping(address => bool)) internal topicIssuerExists;

    event ClaimAdded(
        uint256 indexed topic,
        uint256 scheme,
        address indexed issuer,
        bytes signature,
        bytes data,
        string uri,
        uint256 expiresAt
    );

    /// @notice Identidad simple: despliegue + owner (espejo de `createIdentity`).
    constructor(address initialOwner) Ownable(initialOwner) {}

    function addClaim(
        uint256 topic,
        uint256 scheme,
        address issuer,
        bytes memory signature,
        bytes memory data,
        string memory uri,
        uint256 expiresAt
    ) external onlyOwner returns (bytes32) {
        return _addClaim(topic, scheme, issuer, signature, data, uri, expiresAt);
    }

    function claimExists(uint256 topic, address issuer) external view returns (bool) {
        return claims[topic][issuer].issuer != address(0);
    }

    function _addClaim(
        uint256 topic,
        uint256 scheme,
        address issuer,
        bytes memory signature,
        bytes memory data,
        string memory uri,
        uint256 expiresAt
    ) internal returns (bytes32) {
        claims[topic][issuer] = Claim({
            topic: topic,
            scheme: scheme,
            issuer: issuer,
            signature: signature,
            data: data,
            uri: uri,
            expiresAt: expiresAt
        });

        if (!topicIssuerExists[topic][issuer]) {
            topicIssuers[topic].push(issuer);
            topicIssuerExists[topic][issuer] = true;
        }

        emit ClaimAdded(topic, scheme, issuer, signature, data, uri, expiresAt);

        bytes32 claimId;
        assembly {
            mstore(0x00, issuer)
            mstore(0x20, topic)
            claimId := keccak256(0x00, 0x40)
        }
        return claimId;
    }
}

/**
 * @title IdentityWithClaimBenchmark
 * @notice LÍNEA BASE DE GAS — espejo no-upgradeable de `createIdentityWithClaim`:
 * despliegue completo + owner + claim inicial en el constructor.
 */
contract IdentityWithClaimBenchmark is IdentityBenchmark {
    constructor(
        address initialOwner,
        uint256 topic,
        uint256 scheme,
        address issuer,
        bytes memory signature,
        bytes memory data,
        string memory uri,
        uint256 expiresAt
    ) IdentityBenchmark(initialOwner) {
        _addClaim(topic, scheme, issuer, signature, data, uri, expiresAt);
    }
}
