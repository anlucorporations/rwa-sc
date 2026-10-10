// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IdentityCloneable} from "./IdentityCloneable.sol";

/**
 * @title IdentityRegistry
 * @dev Registry that manages investor identities
 * Links wallet addresses to their identity contracts
 */
contract IdentityRegistry is Ownable {
    // Mapping from wallet address to identity contract
    mapping(address => IdentityCloneable) private identities;

    // Mapping to track registered addresses
    mapping(address => bool) private registered;

    // Array of all registered addresses for iteration
    address[] private registeredAddresses;

    event IdentityRegistered(address indexed wallet, address indexed identity);
    event IdentityRemoved(address indexed wallet, address indexed identity);
    event IdentityUpdated(address indexed wallet, address indexed oldIdentity, address indexed newIdentity);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Register an identity for a wallet
     * @param _wallet Wallet address
     * @param _identity Identity contract address
     */
    function registerIdentity(address _wallet, address _identity) external onlyOwner {
        require(_wallet != address(0), "Invalid wallet address");
        require(_identity != address(0), "Invalid identity address");
        require(!registered[_wallet], "Wallet already registered");

        identities[_wallet] = IdentityCloneable(_identity);
        registered[_wallet] = true;
        registeredAddresses.push(_wallet);

        emit IdentityRegistered(_wallet, _identity);
    }

    /**
     * @dev Update an identity for a wallet
     * @param _wallet Wallet address
     * @param _identity New identity contract address
     */
    function updateIdentity(address _wallet, address _identity) external onlyOwner {
        require(_wallet != address(0), "Invalid wallet address");
        require(_identity != address(0), "Invalid identity address");
        require(registered[_wallet], "Wallet not registered");

        address oldIdentity = address(identities[_wallet]);
        identities[_wallet] = IdentityCloneable(_identity);

        emit IdentityUpdated(_wallet, oldIdentity, _identity);
    }

    /**
     * @dev Remove an identity
     * @param _wallet Wallet address
     */
    function removeIdentity(address _wallet) external onlyOwner {
        require(registered[_wallet], "Wallet not registered");

        address identityAddress = address(identities[_wallet]);
        delete identities[_wallet];
        registered[_wallet] = false;

        // Remove from registered addresses array
        for (uint256 i = 0; i < registeredAddresses.length; i++) {
            if (registeredAddresses[i] == _wallet) {
                registeredAddresses[i] = registeredAddresses[registeredAddresses.length - 1];
                registeredAddresses.pop();
                break;
            }
        }

        emit IdentityRemoved(_wallet, identityAddress);
    }

    /**
     * @dev Get identity contract for a wallet
     * @param _wallet Wallet address
     */
    function getIdentity(address _wallet) external view returns (address) {
        return address(identities[_wallet]);
    }

    /**
     * @dev Check if a wallet is registered
     * @param _wallet Wallet address
     */
    function isRegistered(address _wallet) external view returns (bool) {
        return registered[_wallet];
    }

    /**
     * @dev Get total number of registered identities
     */
    function getRegisteredCount() external view returns (uint256) {
        return registeredAddresses.length;
    }

    /**
     * @dev Get registered address at index
     */
    function getRegisteredAddress(uint256 index) external view returns (address) {
        require(index < registeredAddresses.length, "Index out of bounds");
        return registeredAddresses[index];
    }
}
