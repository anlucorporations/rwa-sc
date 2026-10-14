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

    /// @dev H-20: indice 1-based de `_wallet` en `registeredAddresses` (`0` = no presente).
    /// Convierte el borrado de O(n) (escaneo) en O(1), manteniendo el swap-and-pop.
    mapping(address => uint256) private addressIndex;

    event IdentityRegistered(address indexed wallet, address indexed identity);
    event IdentityRemoved(address indexed wallet, address indexed identity);
    event IdentityUpdated(address indexed wallet, address indexed oldIdentity, address indexed newIdentity);

    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Register an identity for a wallet
     * @param _wallet Wallet address
     * @param _identity Identity contract address
     *
     * HB-13: `_identity` must be a contract (`code.length > 0`). Registering an EOA leaves the
     * wallet pointing at an address with no claim logic, so `isVerified` could never be satisfied
     * meaningfully; it is rejected explicitly.
     */
    function registerIdentity(address _wallet, address _identity) external onlyOwner {
        require(_wallet != address(0), "Invalid wallet address");
        require(_identity != address(0), "Invalid identity address");
        require(_identity.code.length > 0, "Identity must be a contract");
        require(!registered[_wallet], "Wallet already registered");

        identities[_wallet] = IdentityCloneable(_identity);
        registered[_wallet] = true;
        registeredAddresses.push(_wallet);
        addressIndex[_wallet] = registeredAddresses.length;

        emit IdentityRegistered(_wallet, _identity);
    }

    /**
     * @dev Update an identity for a wallet
     * @param _wallet Wallet address
     * @param _identity New identity contract address
     *
     * HB-13: same contract check as `registerIdentity`.
     */
    function updateIdentity(address _wallet, address _identity) external onlyOwner {
        require(_wallet != address(0), "Invalid wallet address");
        require(_identity != address(0), "Invalid identity address");
        require(_identity.code.length > 0, "Identity must be a contract");
        require(registered[_wallet], "Wallet not registered");

        address oldIdentity = address(identities[_wallet]);
        identities[_wallet] = IdentityCloneable(_identity);

        emit IdentityUpdated(_wallet, oldIdentity, _identity);
    }

    /**
     * @dev Remove an identity
     * @param _wallet Wallet address
     *
     * HB-14 (Ciclo 8): ademas de `registered[_wallet]`, se comprueba explicitamente que `_wallet`
     * figure en `registeredAddresses` antes de dar por hecho el borrado. Si el mapping y el array
     * se desincronizaran, la funcion revierte con `"Wallet not in registered addresses"` en lugar
     * de emitir `IdentityRemoved` sin haber borrado nada. Se conserva el *swap-and-pop* y el evento.
     */
    function removeIdentity(address _wallet) external onlyOwner {
        require(registered[_wallet], "Wallet not registered");

        address identityAddress = address(identities[_wallet]);
        delete identities[_wallet];
        registered[_wallet] = false;

        // Remove from registered addresses array (swap-and-pop) en O(1) via `addressIndex`
        // (HB-14: se verifica la pertenencia con el indice, no con un escaneo).
        uint256 idx = addressIndex[_wallet];
        require(idx != 0, "Wallet not in registered addresses");

        uint256 i = idx - 1;
        uint256 lastIndex = registeredAddresses.length - 1;
        if (i != lastIndex) {
            address moved = registeredAddresses[lastIndex];
            registeredAddresses[i] = moved;
            addressIndex[moved] = idx; // indice 1-based del movido = i + 1
        }
        registeredAddresses.pop();
        delete addressIndex[_wallet];

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

    /**
     * @dev H-20: vista paginada de `registeredAddresses`. `offset >= length` o `limit == 0`
     * devuelve un array vacio.
     * @param offset Indice inicial (0-based)
     * @param limit Numero maximo de elementos
     */
    function getRegisteredAddressesPaginated(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory page)
    {
        uint256 total = registeredAddresses.length;
        if (offset >= total || limit == 0) {
            return new address[](0);
        }
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        page = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = registeredAddresses[i];
        }
    }
}
