// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ClaimTopicsRegistryCloneable} from "./ClaimTopicsRegistryCloneable.sol";

/**
 * @title ClaimTopicsRegistryCloneFactory
 * @dev Factory contract to create ClaimTopicsRegistry clones using EIP-1167 minimal proxy pattern
 * This significantly reduces gas costs when deploying multiple registry contracts
 */
contract ClaimTopicsRegistryCloneFactory is Ownable {
    using Clones for address;

    // Implementation contract that will be cloned
    address public immutable implementation;

    // Mapping to track all created registries by owner
    mapping(address => address[]) public ownerRegistries;

    // Array of all created registries
    address[] public allRegistries;

    // Optional: Mapping to track which registry belongs to which token
    mapping(address => address) public tokenRegistry;

    // Events
    event RegistryCreated(address indexed registry, address indexed owner);
    event RegistryCreatedForToken(address indexed registry, address indexed token, address indexed owner);

    /**
     * @dev Constructor
     * @param initialOwner Owner of the factory contract
     */
    constructor(address initialOwner) Ownable(initialOwner) {
        // Deploy the implementation contract
        implementation = address(new ClaimTopicsRegistryCloneable());
    }

    /**
     * @dev Create a new ClaimTopicsRegistry clone
     * @param owner Owner address for the registry
     * @return registry The address of the newly created registry clone
     */
    function createRegistry(address owner) external returns (address registry) {
        require(owner != address(0), "Invalid owner address");

        // Clone the implementation contract
        registry = implementation.clone();

        // Initialize the clone
        ClaimTopicsRegistryCloneable(registry).initialize(owner);

        // Track the created registry
        ownerRegistries[owner].push(registry);
        allRegistries.push(registry);

        emit RegistryCreated(registry, owner);

        return registry;
    }

    /**
     * @dev Create a new ClaimTopicsRegistry clone for a specific token
     * @param owner Owner address for the registry
     * @param token Token address this registry will be associated with
     * @return registry The address of the newly created registry clone
     */
    function createRegistryForToken(
        address owner,
        address token
    ) external returns (address registry) {
        require(owner != address(0), "Invalid owner address");
        require(token != address(0), "Invalid token address");
        require(tokenRegistry[token] == address(0), "Token already has a registry");

        // Clone the implementation contract
        registry = implementation.clone();

        // Initialize the clone
        ClaimTopicsRegistryCloneable(registry).initialize(owner);

        // Track the created registry
        ownerRegistries[owner].push(registry);
        allRegistries.push(registry);
        tokenRegistry[token] = registry;

        emit RegistryCreatedForToken(registry, token, owner);

        return registry;
    }

    /**
     * @dev Create a new ClaimTopicsRegistry clone with initial topics
     * @param owner Owner address for the registry
     * @param initialTopics Array of initial claim topics to add
     * @return registry The address of the newly created registry clone
     */
    function createRegistryWithTopics(
        address owner,
        uint256[] memory initialTopics
    ) external returns (address registry) {
        require(owner != address(0), "Invalid owner address");

        // Clone the implementation contract
        registry = implementation.clone();

        // Initialize the clone with factory as temporary owner
        ClaimTopicsRegistryCloneable registryContract = ClaimTopicsRegistryCloneable(registry);
        registryContract.initialize(address(this));

        // Add initial topics
        for (uint256 i = 0; i < initialTopics.length; i++) {
            registryContract.addClaimTopic(initialTopics[i]);
        }

        // Transfer ownership to the actual owner
        registryContract.transferOwnership(owner);

        // Track the created registry
        ownerRegistries[owner].push(registry);
        allRegistries.push(registry);

        emit RegistryCreated(registry, owner);

        return registry;
    }

    /**
     * @dev Create a new ClaimTopicsRegistry clone for a token with initial topics
     * @param owner Owner address for the registry
     * @param token Token address this registry will be associated with
     * @param initialTopics Array of initial claim topics to add
     * @return registry The address of the newly created registry clone
     */
    function createRegistryForTokenWithTopics(
        address owner,
        address token,
        uint256[] memory initialTopics
    ) external returns (address registry) {
        require(owner != address(0), "Invalid owner address");
        require(token != address(0), "Invalid token address");
        require(tokenRegistry[token] == address(0), "Token already has a registry");

        // Clone the implementation contract
        registry = implementation.clone();

        // Initialize the clone with factory as temporary owner
        ClaimTopicsRegistryCloneable registryContract = ClaimTopicsRegistryCloneable(registry);
        registryContract.initialize(address(this));

        // Add initial topics
        for (uint256 i = 0; i < initialTopics.length; i++) {
            registryContract.addClaimTopic(initialTopics[i]);
        }

        // Transfer ownership to the actual owner
        registryContract.transferOwnership(owner);

        // Track the created registry
        ownerRegistries[owner].push(registry);
        allRegistries.push(registry);
        tokenRegistry[token] = registry;

        emit RegistryCreatedForToken(registry, token, owner);

        return registry;
    }

    /**
     * @dev Get all registries created by a specific owner
     * @param owner The owner address
     * @return Array of registry contract addresses
     */
    function getRegistriesByOwner(address owner) external view returns (address[] memory) {
        return ownerRegistries[owner];
    }

    /**
     * @dev Get total number of registries created
     * @return Total count of registries
     */
    function getTotalRegistries() external view returns (uint256) {
        return allRegistries.length;
    }

    /**
     * @dev Get registry at specific index
     * @param index Index in the allRegistries array
     * @return Registry address
     */
    function getRegistryAt(uint256 index) external view returns (address) {
        require(index < allRegistries.length, "Index out of bounds");
        return allRegistries[index];
    }

    /**
     * @dev Get registry associated with a token
     * @param token Token address
     * @return Registry address (or address(0) if not set)
     */
    function getRegistryForToken(address token) external view returns (address) {
        return tokenRegistry[token];
    }

    /**
     * @dev Calculate the gas cost savings of using clones
     * @return Approximate gas saved per clone vs full deployment
     */
    function getGasSavingsInfo() external pure returns (string memory) {
        return "Clone deployment: ~50k gas vs Full deployment: ~400k gas. Savings: ~350k gas per Registry!";
    }
}

