// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TokenCloneable} from "./TokenCloneable.sol";

/**
 * @title TokenCloneFactory
 * @dev Factory contract to create Token clones using EIP-1167 minimal proxy pattern
 * This significantly reduces gas costs when deploying multiple Token contracts
 */
contract TokenCloneFactory is Ownable {
    using Clones for address;

    // Implementation contract that will be cloned
    address public immutable implementation;

    // Mapping to track all created tokens by admin
    mapping(address => address[]) public adminTokens;

    // Array of all created tokens
    address[] public allTokens;

    // Events
    event TokenCreated(
        address indexed token,
        address indexed admin,
        string name,
        string symbol,
        uint8 decimals
    );

    /**
     * @dev Constructor
     * @param initialOwner Owner of the factory contract
     */
    constructor(address initialOwner) Ownable(initialOwner) {
        // Deploy the implementation contract
        implementation = address(new TokenCloneable());
    }

    /**
     * @dev Create a new Token clone
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param decimals_ Token decimals
     * @param admin Admin address for the token
     * @return token The address of the newly created Token clone
     */
    function createToken(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address admin
    ) external returns (address token) {
        require(admin != address(0), "Invalid admin address");
        require(bytes(name_).length > 0, "Token name required");
        require(bytes(symbol_).length > 0, "Token symbol required");

        // Clone the implementation contract
        token = implementation.clone();

        // Initialize the clone
        TokenCloneable(token).initialize(name_, symbol_, decimals_, admin);

        // Track the created token
        adminTokens[admin].push(token);
        allTokens.push(token);

        emit TokenCreated(token, admin, name_, symbol_, decimals_);

        return token;
    }

    /**
     * @dev Create a new Token clone with registries already set
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param decimals_ Token decimals
     * @param admin Admin address for the token
     * @param identityRegistry Identity registry address
     * @param trustedIssuersRegistry Trusted issuers registry address
     * @param claimTopicsRegistry Claim topics registry address
     * @return token The address of the newly created Token clone
     */
    function createTokenWithRegistries(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address admin,
        address identityRegistry,
        address trustedIssuersRegistry,
        address claimTopicsRegistry
    ) external returns (address token) {
        require(admin != address(0), "Invalid admin address");
        require(bytes(name_).length > 0, "Token name required");
        require(bytes(symbol_).length > 0, "Token symbol required");

        // Clone the implementation contract
        token = implementation.clone();

        // Initialize the clone with factory as temporary admin
        TokenCloneable tokenContract = TokenCloneable(token);
        tokenContract.initialize(name_, symbol_, decimals_, address(this));

        // Set registries if provided
        if (identityRegistry != address(0)) {
            tokenContract.setIdentityRegistry(identityRegistry);
        }
        if (trustedIssuersRegistry != address(0)) {
            tokenContract.setTrustedIssuersRegistry(trustedIssuersRegistry);
        }
        if (claimTopicsRegistry != address(0)) {
            tokenContract.setClaimTopicsRegistry(claimTopicsRegistry);
        }

        // Grant all roles to the actual admin
        tokenContract.grantRole(tokenContract.DEFAULT_ADMIN_ROLE(), admin);
        tokenContract.grantRole(tokenContract.AGENT_ROLE(), admin);
        tokenContract.grantRole(tokenContract.COMPLIANCE_ROLE(), admin);

        // Renounce factory's roles (must be done after granting to admin)
        tokenContract.renounceRole(tokenContract.DEFAULT_ADMIN_ROLE(), address(this));
        tokenContract.renounceRole(tokenContract.AGENT_ROLE(), address(this));
        tokenContract.renounceRole(tokenContract.COMPLIANCE_ROLE(), address(this));

        // Track the created token
        adminTokens[admin].push(token);
        allTokens.push(token);

        emit TokenCreated(token, admin, name_, symbol_, decimals_);

        return token;
    }

    /**
     * @dev Get all tokens created for a specific admin
     * @param admin The admin address
     * @return Array of Token contract addresses
     */
    function getTokensByAdmin(address admin) external view returns (address[] memory) {
        return adminTokens[admin];
    }

    /**
     * @dev Get total number of tokens created
     * @return Total count of tokens
     */
    function getTotalTokens() external view returns (uint256) {
        return allTokens.length;
    }

    /**
     * @dev Get token at specific index
     * @param index Index in the allTokens array
     * @return Token address
     */
    function getTokenAt(uint256 index) external view returns (address) {
        require(index < allTokens.length, "Index out of bounds");
        return allTokens[index];
    }

    /**
     * @dev Calculate the gas cost savings of using clones
     * @return Approximate gas saved per clone vs full deployment
     */
    function getGasSavingsInfo() external pure returns (string memory) {
        return "Clone deployment: ~50k gas vs Full deployment: ~3M gas. Savings: ~2.95M gas per Token!";
    }
}

