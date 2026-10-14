// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
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
 *
 * Anti-reentrancy (RF-002 / H-18): the state-changing entry points that call external contracts
 * (`addModule`, `removeModule`, `transferred`, `created`, `destroyed`) are `nonReentrant`. The guard
 * is the stateless OpenZeppelin `ReentrancyGuard` (ERC-7201 namespaced storage), independent from the
 * token's own guard, so a malicious module cannot re-enter the aggregator during a notification loop.
 * `canTransfer` is `view` and needs no guard.
 *
 * ERC-165 (RF-003 / HB-04): the aggregator is itself a compliance module of the token, so it
 * implements `supportsInterface` (ICompliance + IERC165) and validates every module registered through
 * `addModule` against `type(ICompliance).interfaceId`, rejecting EOAs and non-conforming contracts.
 */
contract ComplianceAggregator is ICompliance, ERC165, Ownable, ReentrancyGuard {
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
     * @dev ERC-165 (RF-003): declara la conformidad con `ICompliance` y `IERC165`.
     * @param interfaceId Interface identifier to query
     * @return bool True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(ICompliance).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Checks, without reverting on a non-contract target, whether `module` declares
     * `type(ICompliance).interfaceId` through ERC-165. An EOA (empty return data) or a contract
     * without `supportsInterface` (call failure or empty/short data) yields `false`.
     * @param module Address to inspect
     * @return bool True if the address is a contract implementing `ICompliance`
     */
    function _implementsCompliance(address module) private view returns (bool) {
        (bool success, bytes memory data) =
            module.staticcall(abi.encodeWithSelector(IERC165.supportsInterface.selector, type(ICompliance).interfaceId));
        return success && data.length >= 32 && abi.decode(data, (bool));
    }

    /**
     * @dev Modifier (RF-012 / CU-16): solo el propio token puede administrar sus modulos. El owner
     * global del aggregator ya **no** puede tocar los modulos de un token ajeno; la autorizacion
     * efectiva la ejerce el sistema de roles del token (`COMPLIANCE_ROLE` en `addModuleThroughAggregator`).
     */
    modifier onlyToken(address token) {
        require(msg.sender == token, "Only token admin can call");
        _;
    }

    /**
     * @dev AF-01 (RF-003/RF-004): comprueba, sin revertir, si un modulo esta vinculado a `token`.
     *
     * - Si el modulo **no expone** `tokenContract()` (staticcall falla), se considera un modulo
     *   multi-token y queda exento.
     * - Si lo expone con retorno mal formado (`data.length < 32`), se rechaza.
     * - Si lo expone, debe devolver exactamente `token` (aqui el token destinatario del alta).
     */
    function _isLinkedToToken(address module, address token) private view returns (bool) {
        (bool success, bytes memory data) = module.staticcall(abi.encodeWithSignature("tokenContract()"));
        if (!success) {
            return true;
        }
        if (data.length < 32) {
            return false;
        }
        return abi.decode(data, (address)) == token;
    }

    /**
     * @dev Add a compliance module for a token
     * Can only be called by the token itself (RF-012 / CU-16)
     * @param token Token address
     * @param module Compliance module address
     *
     * AF-01: ademas de ERC-165, se exige que un modulo de un solo token este vinculado al token
     * destinatario (`module.tokenContract() == token`). Los modulos multi-token que no exponen
     * `tokenContract()` quedan exentos.
     */
    function addModule(address token, address module) external nonReentrant onlyToken(token) {
        require(token != address(0), "Invalid token address");
        require(module != address(0), "Invalid module address");
        require(_implementsCompliance(module), "Module does not implement ICompliance");
        require(_isLinkedToToken(module, token), "Module not linked to this token");
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
     * Can only be called by the token itself (RF-012 / CU-16)
     * @param token Token address
     * @param module Compliance module address
     */
    function removeModule(address token, address module) external nonReentrant onlyToken(token) {
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
    function canTransfer(address from, address to, uint256 amount) external view override returns (bool) {
        address token = msg.sender;

        // RF-012 (Ciclo 7): fail-closed. Un token no registrado o sin modulos activos NO puede
        // transferir (antes se permitia todo: fail-open H-22 de la auditoria V1).
        if (!_isTokenRegistered[token] || tokenModules[token].length == 0) {
            return false;
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
    function transferred(address from, address to, uint256 amount) external override nonReentrant {
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
    function created(address to, uint256 amount) external override nonReentrant {
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
    function destroyed(address from, uint256 amount) external override nonReentrant {
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

    /**
     * @dev H-20: vista paginada de los modulos de un token. `offset >= count` o `limit == 0`
     * devuelve un array vacio.
     * @param token Token address
     * @param offset Indice inicial (0-based)
     * @param limit Numero maximo de elementos
     */
    function getModulesPaginated(address token, uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory page)
    {
        uint256 total = tokenModules[token].length;
        if (offset >= total || limit == 0) {
            return new address[](0);
        }
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        page = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = address(tokenModules[token][i]);
        }
    }

    /**
     * @dev H-20: vista paginada de los tokens registrados. `offset >= count` o `limit == 0`
     * devuelve un array vacio.
     * @param offset Indice inicial (0-based)
     * @param limit Numero maximo de elementos
     */
    function getTokensPaginated(uint256 offset, uint256 limit) external view returns (address[] memory page) {
        uint256 total = tokens.length;
        if (offset >= total || limit == 0) {
            return new address[](0);
        }
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        page = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = tokens[i];
        }
    }
}
