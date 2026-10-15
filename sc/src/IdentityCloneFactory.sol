// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IdentityCloneable} from "./IdentityCloneable.sol";

/**
 * @title IdentityCloneFactory
 * @dev Factory contract to create Identity clones using EIP-1167 minimal proxy pattern
 * This significantly reduces gas costs when deploying multiple Identity contracts
 */
contract IdentityCloneFactory is Ownable {
    using Clones for address;

    // Implementation contract that will be cloned
    address public immutable implementation;

    // Mapping to track all created identities
    mapping(address => address[]) public userIdentities;

    // Array of all created identities
    address[] public allIdentities;

    /// @dev H-07: allowlist de creadores (ver `TokenCloneFactory`). `owner()` siempre puede crear.
    mapping(address => bool) public authorizedCreators;

    // Events
    event IdentityCreated(address indexed identity, address indexed owner);
    event ImplementationUpdated(address indexed newImplementation);

    /// @dev H-07: traza de la allowlist de creadores.
    event CreatorAuthorized(address indexed creator, bool authorized);

    /**
     * @dev H-07: solo el owner de la factory o una direccion autorizada pueden crear.
     */
    modifier onlyCreator() {
        require(msg.sender == owner() || authorizedCreators[msg.sender], "Not authorized to create");
        _;
    }

    /**
     * @dev Constructor
     * @param initialOwner Owner of the factory contract
     */
    constructor(address initialOwner) Ownable(initialOwner) {
        // Deploy the implementation contract
        implementation = address(new IdentityCloneable());
    }

    /**
     * @dev H-07: autoriza o revoca una direccion para crear identidades con esta factory.
     */
    function setAuthorizedCreator(address creator, bool authorized) external onlyOwner {
        require(creator != address(0), "Invalid creator address");
        authorizedCreators[creator] = authorized;
        emit CreatorAuthorized(creator, authorized);
    }

    /**
     * @dev Create a new Identity clone for a user
     * @param owner The owner of the new Identity contract
     * @return identity The address of the newly created Identity clone
     */
    function createIdentity(address owner) external onlyCreator returns (address identity) {
        require(owner != address(0), "Invalid owner address");

        // Clone the implementation contract
        identity = implementation.clone();

        // Initialize the clone with the owner
        IdentityCloneable(identity).initialize(owner);

        // Track the created identity
        userIdentities[owner].push(identity);
        allIdentities.push(identity);

        emit IdentityCreated(identity, owner);

        return identity;
    }

    /**
     * @dev Create a new Identity clone and add a claim in one transaction
     * @param owner The owner of the new Identity contract
     * @param topic Claim topic
     * @param scheme Signature scheme
     * @param issuer Claim issuer address
     * @param signature Claim signature
     * @param data Claim data
     * @param uri Claim URI
     * @param expiresAt Claim expiration timestamp (signed and stored; enforced by RF-013)
     * @return identity The address of the newly created Identity clone
     *
     * @dev RF-001 (D-020): la firma es EIP-712 y su digest incluye el
     * `verifyingContract` (la direccion del clon) y el `walletOwner`. Como el clon se
     * inicializa con la factory como owner temporal para poder llamar a `addClaim`
     * (onlyOwner), el `walletOwner` firmado en esta ruta concreta es la direccion de
     * la factory (ver D-027). El anti-replay entre identidades sigue garantizado por
     * `verifyingContract`, que es unico por clon.
     *
     * AF-04: **solo el propio titular** (`msg.sender == owner`) puede consumir la firma. Como el
     * `verifyingContract` es predecible (CREATE), un tercero podia hacer *front-running*: consumia
     * la firma y la transaccion legitima del titular revertia. Al exigir que el llamante sea el
     * titular, el front-running deja de tener efecto (la copia solo la puede enviar el titular).
     * Esta ruta no usa `onlyCreator` porque es autoservicio del titular, no una creacion delegada.
     */
    function createIdentityWithClaim(
        address owner,
        uint256 topic,
        uint256 scheme,
        address issuer,
        bytes memory signature,
        bytes memory data,
        string memory uri,
        uint256 expiresAt
    ) external returns (address identity) {
        require(owner != address(0), "Invalid owner address");
        require(msg.sender == owner, "Only owner can create with claim");

        // Clone the implementation contract
        identity = implementation.clone();

        // Initialize the clone with factory as temporary owner
        IdentityCloneable identityContract = IdentityCloneable(identity);
        identityContract.initialize(address(this));

        // Add the claim before transferring ownership
        identityContract.addClaim(topic, scheme, issuer, signature, data, uri, expiresAt);

        // Transfer ownership to the actual owner
        identityContract.transferOwnership(owner);

        // Track the created identity
        userIdentities[owner].push(identity);
        allIdentities.push(identity);

        emit IdentityCreated(identity, owner);

        return identity;
    }

    /**
     * @dev Get all identities created for a specific user
     * @param user The user address
     * @return Array of Identity contract addresses
     */
    function getIdentitiesByOwner(address user) external view returns (address[] memory) {
        return userIdentities[user];
    }

    /**
     * @dev Get total number of identities created
     * @return Total count of identities
     */
    function getTotalIdentities() external view returns (uint256) {
        return allIdentities.length;
    }

    /**
     * @dev Get identity at specific index
     * @param index Index in the allIdentities array
     * @return Identity address
     */
    function getIdentityAt(uint256 index) external view returns (address) {
        require(index < allIdentities.length, "Index out of bounds");
        return allIdentities[index];
    }

    /**
     * @dev Calculate the gas cost savings of using clones
     * @return Approximate gas saved per clone vs full deployment
     */
    function getGasSavingsInfo() external pure returns (string memory) {
        return "Clone deployment: ~45k gas vs Full deployment: ~800k gas. Savings: ~755k gas per Identity!";
    }
}
