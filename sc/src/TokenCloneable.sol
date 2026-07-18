// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IdentityRegistry} from "./IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "./TrustedIssuersRegistry.sol";
import {IClaimTopicsRegistry} from "./IClaimTopicsRegistry.sol";
import {ICompliance} from "./ICompliance.sol";
import {ComplianceAggregator} from "./compliance/ComplianceAggregator.sol";

/**
 * @title TokenCloneable
 * @dev ERC-3643 compliant security token that can be cloned using EIP-1167 minimal proxy pattern
 * Uses Initializable pattern instead of constructor for clone compatibility
 */
contract TokenCloneable is ERC20Upgradeable, AccessControlUpgradeable, PausableUpgradeable {
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

    // Flag to bypass compliance for forced transfers
    bool private bypassCompliance;

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
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address admin
    ) external initializer {
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
     * @dev Add a compliance module
     */
    function addComplianceModule(address module) external onlyRole(COMPLIANCE_ROLE) {
        require(module != address(0), "Invalid module address");
        complianceModules.push(ICompliance(module));
        emit ComplianceModuleAdded(module);
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

    /**
     * @dev Mint new tokens
     */
    function mint(address to, uint256 amount) external onlyRole(AGENT_ROLE) {
        require(isVerified(to), "Recipient not verified");

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
     */
    function burn(address from, uint256 amount) external onlyRole(AGENT_ROLE) {
        _burn(from, amount);

        // Notify compliance modules
        for (uint256 i = 0; i < complianceModules.length; i++) {
            complianceModules[i].destroyed(from, amount);
        }
    }

    /**
     * @dev Forced transfer by agent (for recovery)
     * Bypasses compliance checks but still requires verification
     */
    function forcedTransfer(address from, address to, uint256 amount) external onlyRole(AGENT_ROLE) {
        require(isVerified(to), "Recipient not verified");

        // Set bypass flag
        bypassCompliance = true;

        // Perform transfer
        _update(from, to, amount);

        // Reset bypass flag
        bypassCompliance = false;

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
     * @dev Override transfer to add compliance checks
     */
    function _update(address from, address to, uint256 amount) internal virtual override {
        // Skip compliance for minting, burning, or forced transfers
        if (from != address(0) && to != address(0) && !bypassCompliance) {
            require(canTransfer(from, to, amount), "Transfer not compliant");
        }

        super._update(from, to, amount);

        // Notify compliance modules (only for transfers, not mint/burn, and not forced transfers)
        if (from != address(0) && to != address(0) && !bypassCompliance) {
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
    function addModuleThroughAggregator(
        address aggregator,
        address module
    ) external onlyRole(COMPLIANCE_ROLE) {
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
    function removeModuleThroughAggregator(
        address aggregator,
        address module
    ) external onlyRole(COMPLIANCE_ROLE) {
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
    function isModuleActiveInAggregator(
        address aggregator,
        address module
    ) external view returns (bool) {
        require(aggregator != address(0), "Invalid aggregator address");
        return ComplianceAggregator(aggregator).isModuleActiveForToken(address(this), module);
    }
}

