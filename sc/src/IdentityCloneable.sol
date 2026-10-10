// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title IdentityCloneable
 * @dev Identity contract that can be cloned using EIP-1167 minimal proxy pattern
 * Uses Initializable pattern instead of constructor for clone compatibility.
 *
 * RF-001 (cierre de H-01): `addClaim` solo acepta claims firmados con EIP-712 por el
 * `issuer` declarado. El dominio EIP-712 es `{name: "RWA-Identity", version: "1",
 * chainId, verifyingContract: address(this)}` (D-020); en clones EIP-1167
 * `verifyingContract` es la direccion del clon, no la de la implementacion.
 *
 * NOTA DE IMPLEMENTACION (D-026): se usa `ECDSA` de OpenZeppelin (malleability: `s`
 * bajo, `v` en {27,28}) pero **no** `EIP712Upgradeable`, porque en OpenZeppelin
 * v5.5.0 ese contrato declara `pragma solidity ^0.8.24` y el proyecto fija
 * `solc_version = 0.8.20` (RF-005/RT-007). La codificacion EIP-712 se reproduce
 * aqui con los mismos typehashes y el prefijo `\x19\x01` de la EIP, de modo que el
 * digest es identico al que produce `EIP712Upgradeable` para el mismo dominio.
 */
contract IdentityCloneable is OwnableUpgradeable {
    // Mapping of claim topic => issuer => claim data
    mapping(uint256 => mapping(address => Claim)) private claims;

    // Mapping to track which issuers have claims for each topic
    mapping(uint256 => address[]) private topicIssuers;

    // Mapping to check if an issuer is in the array (to avoid duplicates)
    mapping(uint256 => mapping(address => bool)) private topicIssuerExists;

    struct Claim {
        uint256 topic;
        uint256 scheme;
        address issuer;
        bytes signature;
        bytes data;
        string uri;
        uint256 expiresAt;
    }

    /// @dev Tipo EIP-712 firmado por el issuer (D-020). `expiresAt` forma parte del
    /// digest: renovar la vigencia exige una nueva firma. Su *enforcement* (rechazar
    /// claims vencidos) es del Ciclo 8/RF-013; aqui solo se firma y se persiste.
    bytes32 public constant CLAIM_TYPEHASH =
        keccak256("Claim(address walletOwner,uint256 topic,uint256 scheme,bytes32 dataHash,uint256 expiresAt)");

    /// @dev `keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")`
    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /// @dev Nombre del dominio exigido por D-020.
    string private constant DOMAIN_NAME = "RWA-Identity";

    /// @dev Version del dominio exigida por D-020.
    string private constant DOMAIN_VERSION = "1";

    event ClaimAdded(
        uint256 indexed topic,
        uint256 scheme,
        address indexed issuer,
        bytes signature,
        bytes data,
        string uri,
        uint256 expiresAt
    );

    event ClaimRemoved(uint256 indexed topic, address indexed issuer);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the identity contract (replaces constructor for clones)
     * @param initialOwner The owner of this identity
     */
    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
    }

    /**
     * @dev Add (or renew) a claim signed with EIP-712 by the declared issuer.
     *
     * Reconstruye el digest EIP-712 con el dominio del clon y `CLAIM_TYPEHASH`, y
     * exige que la firma recuperada sea exactamente `_issuer`. El `walletOwner`
     * firmado se toma de `owner()` de esta identidad, lo que impide reutilizar una
     * firma entre titulares distintos (anti-replay).
     *
     * Reintento (D-018): si ya existe un claim para el mismo par `(topic, issuer)`,
     * se sobrescribe (renovacion) **solo** tras validar la firma; el issuer no se
     * duplica en `topicIssuers`.
     *
     * Alcance de la autorizacion (D-025): este contrato **no** comprueba que el
     * issuer este autorizado para el topic. Esa comprobacion la impone de forma
     * autoritativa `TokenCloneable.isVerified` contra el `TrustedIssuersRegistry`
     * del token: una firma valida solo prueba el consentimiento del issuer, y un
     * issuer no autorizado nunca cuenta porque el token no lo reconoce.
     *
     * `_expiresAt` queda firmado y almacenado; su *enforcement* corresponde al
     * Ciclo 8/RF-013, no a este ciclo.
     *
     * @param _topic Claim topic (e.g., 1 for KYC)
     * @param _scheme Signature scheme (only 1 = ECDSA supported)
     * @param _issuer Address of the claim issuer (must equal the recovered signer)
     * @param _signature 65-byte ECDSA signature (r || s || v, v in {27,28})
     * @param _data Claim data (committed as keccak256(_data) inside the digest)
     * @param _uri URI for additional claim information
     * @param _expiresAt Expiration timestamp, signed and stored (enforced by RF-013)
     * @return claimId Deterministic id: keccak256(abi.encode(issuer, topic))
     */
    function addClaim(
        uint256 _topic,
        uint256 _scheme,
        address _issuer,
        bytes memory _signature,
        bytes memory _data,
        string memory _uri,
        uint256 _expiresAt
    ) external onlyOwner returns (bytes32) {
        require(_scheme == 1, "Unsupported scheme");
        require(_issuer != address(0), "Invalid issuer address");
        require(_signature.length == 65, "Invalid signature length");

        // El `walletOwner` firmado es el owner de esta identidad: una firma emitida
        // para otra identidad (u otro titular) no puede recuperar a `_issuer`.
        bytes32 structHash =
            keccak256(abi.encode(CLAIM_TYPEHASH, owner(), _topic, _scheme, keccak256(_data), _expiresAt));
        bytes32 digest = _hashTypedDataV4(structHash);

        // ECDSA.tryRecover aplica las comprobaciones de maleabilidad de OpenZeppelin
        // (s en la mitad inferior y v en {27,28}); mapeamos el fallo a los literales
        // de RF-001 sin debilitar la comprobacion.
        (address recovered,,) = ECDSA.tryRecover(digest, _signature);
        require(recovered != address(0), "Invalid signature");
        require(recovered == _issuer, "Signature signer mismatch");

        claims[_topic][_issuer] = Claim({
            topic: _topic,
            scheme: _scheme,
            issuer: _issuer,
            signature: _signature,
            data: _data,
            uri: _uri,
            expiresAt: _expiresAt
        });

        // Track this issuer for this topic (sin duplicados al renovar, D-018)
        if (!topicIssuerExists[_topic][_issuer]) {
            topicIssuers[_topic].push(_issuer);
            topicIssuerExists[_topic][_issuer] = true;
        }

        emit ClaimAdded(_topic, _scheme, _issuer, _signature, _data, _uri, _expiresAt);

        bytes32 claimId;
        assembly {
            // Store issuer at memory position 0x00
            mstore(0x00, _issuer)
            // Store topic at memory position 0x20
            mstore(0x20, _topic)
            // Hash 64 bytes (2 * 32 bytes)
            claimId := keccak256(0x00, 0x40)
        }
        return claimId;
    }

    /**
     * @dev Remove a claim from the identity
     * @param _topic Claim topic
     * @param _issuer Issuer address
     */
    function removeClaim(uint256 _topic, address _issuer) external onlyOwner returns (bool) {
        delete claims[_topic][_issuer];

        // Remove issuer from tracking array
        if (topicIssuerExists[_topic][_issuer]) {
            address[] storage issuers = topicIssuers[_topic];
            for (uint256 i = 0; i < issuers.length; i++) {
                if (issuers[i] == _issuer) {
                    issuers[i] = issuers[issuers.length - 1];
                    issuers.pop();
                    break;
                }
            }
            topicIssuerExists[_topic][_issuer] = false;
        }

        emit ClaimRemoved(_topic, _issuer);
        return true;
    }

    /**
     * @dev Get a claim
     * @param _topic Claim topic
     * @param _issuer Issuer address
     */
    function getClaim(uint256 _topic, address _issuer)
        external
        view
        returns (
            uint256 topic,
            uint256 scheme,
            address issuer,
            bytes memory signature,
            bytes memory data,
            string memory uri,
            uint256 expiresAt
        )
    {
        Claim memory claim = claims[_topic][_issuer];
        return (claim.topic, claim.scheme, claim.issuer, claim.signature, claim.data, claim.uri, claim.expiresAt);
    }

    /**
     * @dev Check if a claim exists
     * @param _topic Claim topic
     * @param _issuer Issuer address
     */
    function claimExists(uint256 _topic, address _issuer) external view returns (bool) {
        return claims[_topic][_issuer].issuer != address(0);
    }

    /**
     * @dev Get all issuers that have issued claims for a specific topic
     * @param _topic Claim topic
     * @return Array of issuer addresses
     */
    function getClaimIssuersForTopic(uint256 _topic) external view returns (address[] memory) {
        return topicIssuers[_topic];
    }

    /**
     * @dev EIP-712 domain separator of this identity clone (D-020).
     *
     * Equivalente a `EIP712Upgradeable._domainSeparatorV4()` de OpenZeppelin v5.5.0:
     * el `chainId` se lee en cada llamada, de modo que una firma creada para otra
     * cadena deja de verificar (proteccion de replay entre cadenas). Ver D-026 para
     * el motivo de no heredar de `EIP712Upgradeable`.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(DOMAIN_NAME)),
                keccak256(bytes(DOMAIN_VERSION)),
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @dev Hash final del struct EIP-712 (`\x19\x01 || domainSeparator || structHash`).
     * Identico a `EIP712Upgradeable._hashTypedDataV4()` de OpenZeppelin.
     */
    function _hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparatorV4(), structHash));
    }
}
