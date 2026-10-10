// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IdentityRegistry} from "./IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "./TrustedIssuersRegistry.sol";
import {IClaimTopicsRegistry} from "./IClaimTopicsRegistry.sol";
import {ICompliance} from "./ICompliance.sol";
import {ComplianceAggregator} from "./compliance/ComplianceAggregator.sol";

/**
 * @title TokenCloneable
 * @dev ERC-3643 compliant security token that can be cloned using EIP-1167 minimal proxy pattern
 * Uses Initializable pattern instead of constructor for clone compatibility
 *
 * Anti-reentrancy design (RF-002 / H-18):
 * - Inherits `ReentrancyGuard` from the OpenZeppelin `contracts` package. In OpenZeppelin v5.5.0 this guard is
 *   stateless (ERC-7201 namespaced storage, `StorageSlot` based) and `ReentrancyGuardUpgradeable` was
 *   removed from `contracts-upgradeable` (see its CHANGELOG); the stateless version is clone-safe
 *   because the guard lives in a fixed namespaced slot that is not part of the linear layout and
 *   defaults to `0 != ENTERED`, so it needs no `initialize` call.
 * - `nonReentrant` is applied to the **external state-changing entry points** that reach external
 *   compliance modules (`transfer`, `transferFrom`, `mint`, `burn`, `forcedTransfer`). A guard on the
 *   internal `_update` would only cover the `transferred` callback but would leave the post-update
 *   `created`/`destroyed` loops of `mint`/`burn` and the `transferred` loop of `forcedTransfer`
 *   unguarded; adding it there *and* on `mint`/`burn` would revert with a nested guard. Guarding the
 *   entry points covers every reentrant path without nesting.
 * - `canTransfer` stays `view` and therefore needs no guard.
 */
contract TokenCloneable is ERC20Upgradeable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuard {
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    // Registry contracts
    IdentityRegistry public identityRegistry;
    TrustedIssuersRegistry public trustedIssuersRegistry;
    IClaimTopicsRegistry public claimTopicsRegistry;

    // Compliance modules
    ICompliance[] public complianceModules;

    // Token information
    string private _tokenName;
    string private _tokenSymbol;
    uint8 private _tokenDecimals;

    event IdentityRegistrySet(address indexed registry);
    event TrustedIssuersRegistrySet(address indexed registry);
    event ClaimTopicsRegistrySet(address indexed registry);
    event ComplianceModuleAdded(address indexed module);
    event ComplianceModuleRemoved(address indexed module);
    event Frozen(address indexed account);
    event Unfrozen(address indexed account);

    // Frozen accounts mapping
    mapping(address => bool) private frozen;

    // ============ RF-004: control de operaciones privilegiadas ============

    /// @dev Destinos autorizados para `forcedTransfer` (RF-004). Fail-closed: si esta vacio, ninguna
    /// recuperacion es posible hasta que admin/compliance autorice explicitamente un destino.
    mapping(address => bool) public authorizedDestinations;

    /// @dev Tope por operacion de `burn` (RF-004). `0` desactiva la operacion (CU-06 A6.5).
    uint256 public maxBurnPerTx;

    /// @dev Tope por operacion de `forcedTransfer` (RF-004). `0` desactiva la operacion (CU-06 A6.5).
    uint256 public maxForcedPerTx;

    /// @dev Tope de suministro (RF-004 / D-022). `0` = sin tope.
    uint256 public maxSupply;

    event DestinationAuthorized(address indexed destination, bool authorized);
    event LimitsUpdated(uint256 maxBurnPerTx, uint256 maxForcedPerTx);
    event MaxSupplyUpdated(uint256 maxSupply);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the token contract (replaces constructor for clones)
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param decimals_ Token decimals
     * @param admin Admin address with all roles
     */
    function initialize(string memory name_, string memory symbol_, uint8 decimals_, address admin)
        external
        initializer
    {
        require(admin != address(0), "Invalid admin address");

        __ERC20_init(name_, symbol_);
        __AccessControl_init();
        __Pausable_init();

        _tokenName = name_;
        _tokenSymbol = symbol_;
        _tokenDecimals = decimals_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AGENT_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);
    }

    /**
     * @dev Returns the number of decimals
     */
    function decimals() public view virtual override returns (uint8) {
        return _tokenDecimals;
    }

    /**
     * @dev Set the identity registry
     */
    function setIdentityRegistry(address registry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(registry != address(0), "Invalid registry address");
        identityRegistry = IdentityRegistry(registry);
        emit IdentityRegistrySet(registry);
    }

    /**
     * @dev Set the trusted issuers registry
     */
    function setTrustedIssuersRegistry(address registry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(registry != address(0), "Invalid registry address");
        trustedIssuersRegistry = TrustedIssuersRegistry(registry);
        emit TrustedIssuersRegistrySet(registry);
    }

    /**
     * @dev Set the claim topics registry
     */
    function setClaimTopicsRegistry(address registry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(registry != address(0), "Invalid registry address");
        claimTopicsRegistry = IClaimTopicsRegistry(registry);
        emit ClaimTopicsRegistrySet(registry);
    }

    /**
     * @dev Add a compliance module.
     * RF-003 (HB-04 / H-17): only contracts that declare `type(ICompliance).interfaceId` through
     * ERC-165 are accepted; EOAs, `address(0)` and non-conforming contracts revert, so a module
     * without `canTransfer`/`transferred`/`created`/`destroyed` can never break the transfer path.
     * Duplicate registrations are rejected.
     */
    function addComplianceModule(address module) external onlyRole(COMPLIANCE_ROLE) {
        require(module != address(0), "Invalid module address");
        require(!_isComplianceModule(module), "Module already added");
        require(_implementsCompliance(module), "Module does not implement ICompliance");
        complianceModules.push(ICompliance(module));
        emit ComplianceModuleAdded(module);
    }

    /**
     * @dev Checks whether `module` is already registered.
     */
    function _isComplianceModule(address module) private view returns (bool) {
        for (uint256 i = 0; i < complianceModules.length; i++) {
            if (address(complianceModules[i]) == module) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Checks, without reverting on a non-contract target, whether `module` declares
     * `type(ICompliance).interfaceId` through ERC-165. An EOA (empty return data) or a contract
     * without `supportsInterface` (call failure or empty/short data) yields `false`.
     */
    function _implementsCompliance(address module) private view returns (bool) {
        (bool success, bytes memory data) =
            module.staticcall(abi.encodeWithSelector(IERC165.supportsInterface.selector, type(ICompliance).interfaceId));
        return success && data.length >= 32 && abi.decode(data, (bool));
    }

    /**
     * @dev Remove a compliance module
     */
    function removeComplianceModule(uint256 index) external onlyRole(COMPLIANCE_ROLE) {
        require(index < complianceModules.length, "Invalid index");
        address module = address(complianceModules[index]);
        complianceModules[index] = complianceModules[complianceModules.length - 1];
        complianceModules.pop();
        emit ComplianceModuleRemoved(module);
    }

    /**
     * @dev Freeze an account
     */
    function freezeAccount(address account) external onlyRole(AGENT_ROLE) {
        frozen[account] = true;
        emit Frozen(account);
    }

    /**
     * @dev Unfreeze an account
     */
    function unfreezeAccount(address account) external onlyRole(AGENT_ROLE) {
        frozen[account] = false;
        emit Unfrozen(account);
    }

    /**
     * @dev Check if account is frozen
     */
    function isFrozen(address account) public view returns (bool) {
        return frozen[account];
    }

    /**
     * @dev Pause token transfers
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause token transfers
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ============ RF-004: administracion de los controles ============

    /// @dev Autoriza o revoca un destino para `forcedTransfer` (RF-004).
    /// CU-06 A6.3: pueden administrarlo `DEFAULT_ADMIN_ROLE` o `COMPLIANCE_ROLE`.
    function setAuthorizedDestination(address destination, bool authorized) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(COMPLIANCE_ROLE, msg.sender), "Not authorized");
        require(destination != address(0), "Invalid destination");
        authorizedDestinations[destination] = authorized;
        emit DestinationAuthorized(destination, authorized);
    }

    /// @dev Fija el tope por operacion de `burn` (RF-004). `0` desactiva la quema (CU-06 A6.5).
    function setMaxBurnPerTx(uint256 value) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(COMPLIANCE_ROLE, msg.sender), "Not authorized");
        maxBurnPerTx = value;
        emit LimitsUpdated(maxBurnPerTx, maxForcedPerTx);
    }

    /// @dev Fija el tope por operacion de `forcedTransfer` (RF-004). `0` desactiva la operacion (CU-06 A6.5).
    function setMaxForcedPerTx(uint256 value) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(COMPLIANCE_ROLE, msg.sender), "Not authorized");
        maxForcedPerTx = value;
        emit LimitsUpdated(maxBurnPerTx, maxForcedPerTx);
    }

    /// @dev Fija el tope de suministro (RF-004 / D-022). `0` = sin tope; no puede quedar por debajo
    /// de `totalSupply()`.
    function setMaxSupply(uint256 value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(value == 0 || value >= totalSupply(), "Max supply below total supply");
        maxSupply = value;
        emit MaxSupplyUpdated(value);
    }

    /**
     * @dev Mint new tokens
     * @dev `nonReentrant` covers the whole path: the compliance pre-check (external `canTransfer`),
     * the `_mint` -> `_update` balance write and the trailing `created` notification loop.
     */
    function mint(address to, uint256 amount) external nonReentrant onlyRole(AGENT_ROLE) {
        require(isVerified(to), "Recipient not verified");

        // RF-004: tope de suministro (0 = sin tope)
        if (maxSupply > 0) {
            require(totalSupply() + amount <= maxSupply, "Max supply exceeded");
        }

        // Check compliance before minting
        for (uint256 i = 0; i < complianceModules.length; i++) {
            require(complianceModules[i].canTransfer(address(0), to, amount), "Mint not compliant");
        }

        _mint(to, amount);

        // Notify compliance modules
        for (uint256 i = 0; i < complianceModules.length; i++) {
            complianceModules[i].created(to, amount);
        }
    }

    /**
     * @dev Burn tokens
     * @dev `nonReentrant` covers `_burn` -> `_update` and the trailing `destroyed` notification loop.
     * RF-004: la quema esta acotada por `maxBurnPerTx` (0 = operacion desactivada, CU-06 A6.5).
     */
    function burn(address from, uint256 amount) external nonReentrant onlyRole(AGENT_ROLE) {
        require(maxBurnPerTx > 0 && amount <= maxBurnPerTx, "Exceeds max burn per tx");

        _burn(from, amount);

        // Notify compliance modules
        for (uint256 i = 0; i < complianceModules.length; i++) {
            complianceModules[i].destroyed(from, amount);
        }
    }

    /**
     * @dev Forced transfer by agent (for recovery)
     * Bypasses compliance checks but still requires verification. This is the **explicit** bypass
     * route (RF-002): it no longer flips a mutable storage flag; instead it calls the internal
     * `_forcedUpdate`, which performs the balance update through `super._update` (skipping the
     * compliance check in the `_update` override) and then notifies the modules here.
     *
     * `from == address(0)` is rejected: before RF-002 that input silently minted through the
     * forced (unchecked) path (CU-04 A4.6 / B-05).
     *
     * RF-004 (Ciclo 5): la recuperacion esta acotada por la **whitelist de destinos**
     * (`authorizedDestinations`, fail-closed: vacia = ninguna recuperacion) y por el **tope por
     * operacion** `maxForcedPerTx` (0 = operacion desactivada, CU-06 A6.5).
     */
    function forcedTransfer(address from, address to, uint256 amount) external nonReentrant onlyRole(AGENT_ROLE) {
        require(from != address(0), "Invalid from address");
        require(authorizedDestinations[to], "Destination not authorized");
        require(maxForcedPerTx > 0 && amount <= maxForcedPerTx, "Exceeds max forced transfer per tx");
        require(isVerified(to), "Recipient not verified");

        // Perform the balance update through the explicit internal bypass route (no storage flag).
        _forcedUpdate(from, to, amount);

        // Notify compliance modules
        for (uint256 i = 0; i < complianceModules.length; i++) {
            complianceModules[i].transferred(from, to, amount);
        }
    }

    /**
     * @dev Check if an address is verified
     */
    function isVerified(address account) public view returns (bool) {
        if (address(identityRegistry) == address(0)) {
            return false;
        }

        if (!identityRegistry.isRegistered(account)) {
            return false;
        }

        // Get identity contract
        address identityAddress = identityRegistry.getIdentity(account);
        if (identityAddress == address(0)) {
            return false;
        }

        // Check if all required claim topics are present
        if (address(claimTopicsRegistry) == address(0)) {
            return true;
        }

        uint256[] memory requiredTopics = claimTopicsRegistry.getClaimTopics();

        for (uint256 i = 0; i < requiredTopics.length; i++) {
            bool hasValidClaim = false;

            // OPTIMIZED: Get issuers that have claims for this topic in the identity
            // Instead of iterating through ALL trusted issuers
            (bool success, bytes memory data) = identityAddress.staticcall(
                abi.encodeWithSignature("getClaimIssuersForTopic(uint256)", requiredTopics[i])
            );

            if (success && data.length > 0) {
                address[] memory claimIssuers = abi.decode(data, (address[]));

                // Now check if ANY of these issuers is trusted and can issue this topic
                for (uint256 j = 0; j < claimIssuers.length; j++) {
                    if (address(trustedIssuersRegistry) != address(0)) {
                        // Verify this issuer is trusted AND can issue this specific topic
                        if (trustedIssuersRegistry.hasClaimTopic(claimIssuers[j], requiredTopics[i])) {
                            hasValidClaim = true;
                            break;
                        }
                    }
                }
            }

            if (!hasValidClaim) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Check if transfer is compliant
     */
    function canTransfer(address from, address to, uint256 amount) public view returns (bool) {
        // Check if paused
        if (paused()) {
            return false;
        }

        // Check if frozen
        if (frozen[from] || frozen[to]) {
            return false;
        }

        // Check if verified
        if (!isVerified(from) || !isVerified(to)) {
            return false;
        }

        // Check compliance modules
        for (uint256 i = 0; i < complianceModules.length; i++) {
            if (!complianceModules[i].canTransfer(from, to, amount)) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Override ERC-20 `transfer` to apply the reentrancy guard at the entry point.
     * The guard stays held while `_update` notifies the compliance modules, so a module that tries
     * to re-enter `transfer`/`transferFrom`/`mint`/`burn`/`forcedTransfer` from its callback reverts
     * with `ReentrancyGuardReentrantCall`.
     */
    function transfer(address to, uint256 value) public virtual override nonReentrant returns (bool) {
        return super.transfer(to, value);
    }

    /**
     * @dev Override ERC-20 `transferFrom` for the same reason as `transfer`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual override nonReentrant returns (bool) {
        return super.transferFrom(from, to, value);
    }

    /**
     * @dev Explicit internal bypass route for `forcedTransfer` (RF-002).
     * Calls `super._update` directly, so it skips both the compliance check and the `transferred`
     * notification of the `_update` override. It is only reachable from `forcedTransfer`, which is
     * `onlyRole(AGENT_ROLE)` and `nonReentrant`, and it writes **no** storage flag.
     */
    function _forcedUpdate(address from, address to, uint256 amount) internal virtual {
        super._update(from, to, amount);
    }

    /**
     * @dev Override transfer to add compliance checks.
     * No guard here on purpose: the five external entry points that reach it (`transfer`,
     * `transferFrom`, `mint`, `burn`, `forcedTransfer`) are guarded, which covers the trailing
     * notification loops as well. A guard here would nest with the guards on `mint`/`burn`.
     */
    function _update(address from, address to, uint256 amount) internal virtual override {
        // Skip compliance for minting and burning (regular transfers only)
        if (from != address(0) && to != address(0)) {
            require(canTransfer(from, to, amount), "Transfer not compliant");
        }

        super._update(from, to, amount);

        // Notify compliance modules (only for transfers, not mint/burn)
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < complianceModules.length; i++) {
                complianceModules[i].transferred(from, to, amount);
            }
        }
    }

    /**
     * @dev Get all compliance modules
     */
    function getComplianceModules() external view returns (address[] memory) {
        address[] memory modules = new address[](complianceModules.length);
        for (uint256 i = 0; i < complianceModules.length; i++) {
            modules[i] = address(complianceModules[i]);
        }
        return modules;
    }

    // ============ ComplianceAggregator Integration ============

    /**
     * @dev Add a compliance module through the ComplianceAggregator
     * @param aggregator ComplianceAggregator address
     * @param module Compliance module address
     */
    function addModuleThroughAggregator(address aggregator, address module) external onlyRole(COMPLIANCE_ROLE) {
        require(aggregator != address(0), "Invalid aggregator address");
        require(module != address(0), "Invalid module address");

        // Check that the aggregator is already added as a compliance module
        bool aggregatorFound = false;
        for (uint256 i = 0; i < complianceModules.length; i++) {
            if (address(complianceModules[i]) == aggregator) {
                aggregatorFound = true;
                break;
            }
        }
        require(aggregatorFound, "Aggregator not added as compliance module");

        // Call aggregator to add the module
        ComplianceAggregator(aggregator).addModule(address(this), module);
    }

    /**
     * @dev Remove a compliance module through the ComplianceAggregator
     * @param aggregator ComplianceAggregator address
     * @param module Compliance module address
     */
    function removeModuleThroughAggregator(address aggregator, address module) external onlyRole(COMPLIANCE_ROLE) {
        require(aggregator != address(0), "Invalid aggregator address");
        require(module != address(0), "Invalid module address");

        // Call aggregator to remove the module
        ComplianceAggregator(aggregator).removeModule(address(this), module);
    }

    /**
     * @dev Get all modules from the ComplianceAggregator
     * @param aggregator ComplianceAggregator address
     * @return Array of module addresses
     */
    function getAggregatorModules(address aggregator) external view returns (address[] memory) {
        require(aggregator != address(0), "Invalid aggregator address");
        return ComplianceAggregator(aggregator).getModules(address(this));
    }

    /**
     * @dev Get module count from the ComplianceAggregator
     * @param aggregator ComplianceAggregator address
     * @return Number of modules
     */
    function getAggregatorModuleCount(address aggregator) external view returns (uint256) {
        require(aggregator != address(0), "Invalid aggregator address");
        return ComplianceAggregator(aggregator).getModuleCount(address(this));
    }

    /**
     * @dev Check if a module is active in the ComplianceAggregator
     * @param aggregator ComplianceAggregator address
     * @param module Module address
     * @return True if module is active
     */
    function isModuleActiveInAggregator(address aggregator, address module) external view returns (bool) {
        require(aggregator != address(0), "Invalid aggregator address");
        return ComplianceAggregator(aggregator).isModuleActiveForToken(address(this), module);
    }
}

