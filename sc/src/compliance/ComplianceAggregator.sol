// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ICompliance} from "../ICompliance.sol";

/**
 * @title ComplianceAggregator
 * @dev Aggregator contract that manages multiple compliance modules per token
 * 
 * This contract acts as a proxy/aggregator that:
 * - Maintains an array of compliance modules per token
 * - Delegates compliance checks to all modules
 * - Allows adding/removing modules dynamically
 * - Implements ICompliance interface for seamless integration
 * 
 * Benefits:
 * - Flexible: Add any compliance module that implements ICompliance
 * - Centralized: Manage multiple tokens' compliance from one contract
 * - Efficient: One aggregator for all tokens instead of N*M modules
 * - Extensible: Add new compliance rules without redeploying
 */
contract ComplianceAggregator is ICompliance, Ownable {
    
    // Mapping: token address => array of compliance modules
    mapping(address => ICompliance[]) private tokenModules;
    
    // Mapping: token address => module address => index in array (for O(1) removal)
    mapping(address => mapping(address => uint256)) private moduleIndex;
    
    // Mapping: token address => module address => is active
    mapping(address => mapping(address => bool)) private isModuleActive;
    
    // Array of all tokens using this aggregator
    address[] private tokens;
    
    // Mapping to check if token is already in the array
    mapping(address => bool) private _isTokenRegistered;
    
    // Events
    event ModuleAdded(address indexed token, address indexed module);
    event ModuleRemoved(address indexed token, address indexed module);
    event TokenRegistered(address indexed token);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Modifier to allow only owner or the token itself
     */
    modifier onlyOwnerOrToken(address token) {
        require(msg.sender == owner() || msg.sender == token, "Only owner or token can call");
        _;
    }

    /**
     * @dev Add a compliance module for a token
     * Can be called by owner (for any token) or by the token itself
     * @param token Token address
     * @param module Compliance module address
     */
    function addModule(address token, address module) external onlyOwnerOrToken(token) {
        require(token != address(0), "Invalid token address");
        require(module != address(0), "Invalid module address");
        require(!isModuleActive[token][module], "Module already added");

        // Register token if not already registered
        if (!_isTokenRegistered[token]) {
            tokens.push(token);
            _isTokenRegistered[token] = true;
            emit TokenRegistered(token);
        }

        // Add module
        moduleIndex[token][module] = tokenModules[token].length;
        tokenModules[token].push(ICompliance(module));
        isModuleActive[token][module] = true;

        emit ModuleAdded(token, module);
    }

    /**
     * @dev Remove a compliance module from a token
     * Can be called by owner (for any token) or by the token itself
     * @param token Token address
     * @param module Compliance module address
     */
    function removeModule(address token, address module) external onlyOwnerOrToken(token) {
        require(isModuleActive[token][module], "Module not active");

        uint256 index = moduleIndex[token][module];
        uint256 lastIndex = tokenModules[token].length - 1;

        // If not the last element, swap with last
        if (index != lastIndex) {
            ICompliance lastModule = tokenModules[token][lastIndex];
            tokenModules[token][index] = lastModule;
            moduleIndex[token][address(lastModule)] = index;
        }

        // Remove last element
        tokenModules[token].pop();
        delete moduleIndex[token][module];
        delete isModuleActive[token][module];

        emit ModuleRemoved(token, module);
    }

    /**
     * @dev Check if a transfer is compliant with all modules
     * @param from Sender address
     * @param to Recipient address
     * @param amount Transfer amount
     * @return bool True if compliant with ALL modules
     */
    function canTransfer(
        address from,
        address to,
        uint256 amount
    ) external view override returns (bool) {
        address token = msg.sender;
        
        // If no modules configured, allow transfer
        if (tokenModules[token].length == 0) {
            return true;
        }

        // Check all modules - all must return true
        for (uint256 i = 0; i < tokenModules[token].length; i++) {
            if (!tokenModules[token][i].canTransfer(from, to, amount)) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Called when a transfer occurs - notify all modules
     * @param from Sender address
     * @param to Recipient address
     * @param amount Transfer amount
     */
    function transferred(
        address from,
        address to,
        uint256 amount
    ) external override {
        address token = msg.sender;
        
        // Notify all modules
        for (uint256 i = 0; i < tokenModules[token].length; i++) {
            tokenModules[token][i].transferred(from, to, amount);
        }
    }

    /**
     * @dev Called when tokens are created (minted) - notify all modules
     * @param to Recipient address
     * @param amount Mint amount
     */
    function created(address to, uint256 amount) external override {
        address token = msg.sender;
        
        // Notify all modules
        for (uint256 i = 0; i < tokenModules[token].length; i++) {
            tokenModules[token][i].created(to, amount);
        }
    }

    /**
     * @dev Called when tokens are destroyed (burned) - notify all modules
     * @param from Address from which tokens are burned
     * @param amount Burn amount
     */
    function destroyed(address from, uint256 amount) external override {
        address token = msg.sender;
        
        // Notify all modules
        for (uint256 i = 0; i < tokenModules[token].length; i++) {
            tokenModules[token][i].destroyed(from, amount);
        }
    }

    // ============ View Functions ============

    /**
     * @dev Get all compliance modules for a token
     * @param token Token address
     * @return Array of compliance module addresses
     */
    function getModules(address token) external view returns (address[] memory) {
        ICompliance[] memory modules = tokenModules[token];
        address[] memory moduleAddresses = new address[](modules.length);
        
        for (uint256 i = 0; i < modules.length; i++) {
            moduleAddresses[i] = address(modules[i]);
        }
        
        return moduleAddresses;
    }

    /**
     * @dev Get number of modules for a token
     * @param token Token address
     * @return Number of active modules
     */
    function getModuleCount(address token) external view returns (uint256) {
        return tokenModules[token].length;
    }

    /**
     * @dev Check if a module is active for a token
     * @param token Token address
     * @param module Module address
     * @return True if module is active
     */
    function isModuleActiveForToken(address token, address module) external view returns (bool) {
        return isModuleActive[token][module];
    }

    /**
     * @dev Get all tokens using this aggregator
     * @return Array of token addresses
     */
    function getTokens() external view returns (address[] memory) {
        return tokens;
    }

    /**
     * @dev Get number of tokens using this aggregator
     * @return Number of registered tokens
     */
    function getTokenCount() external view returns (uint256) {
        return tokens.length;
    }

    /**
     * @dev Check if a token is registered
     * @param token Token address
     * @return True if token is registered
     */
    function isTokenRegistered(address token) external view returns (bool) {
        return _isTokenRegistered[token];
    }

    /**
     * @dev Get module at specific index for a token
     * @param token Token address
     * @param index Module index
     * @return Module address
     */
    function getModuleAt(address token, uint256 index) external view returns (address) {
        require(index < tokenModules[token].length, "Index out of bounds");
        return address(tokenModules[token][index]);
    }
}
