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

    // Events
    event IdentityCreated(address indexed identity, address indexed owner);
    event ImplementationUpdated(address indexed newImplementation);

    /**
     * @dev Constructor
     * @param initialOwner Owner of the factory contract
     */
    constructor(address initialOwner) Ownable(initialOwner) {
        // Deploy the implementation contract
        implementation = address(new IdentityCloneable());
    }

    /**
     * @dev Create a new Identity clone for a user
     * @param owner The owner of the new Identity contract
     * @return identity The address of the newly created Identity clone
     */
    function createIdentity(address owner) external returns (address identity) {
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
     * @return identity The address of the newly created Identity clone
     */
    function createIdentityWithClaim(
        address owner,
        uint256 topic,
        uint256 scheme,
        address issuer,
        bytes memory signature,
        bytes memory data,
        string memory uri
    ) external returns (address identity) {
        require(owner != address(0), "Invalid owner address");

        // Clone the implementation contract
        identity = implementation.clone();

        // Initialize the clone with factory as temporary owner
        IdentityCloneable identityContract = IdentityCloneable(identity);
        identityContract.initialize(address(this));

        // Add the claim before transferring ownership
        identityContract.addClaim(topic, scheme, issuer, signature, data, uri);

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
