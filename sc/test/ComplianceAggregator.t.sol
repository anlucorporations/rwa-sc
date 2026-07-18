// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ComplianceAggregator} from "../src/compliance/ComplianceAggregator.sol";
import {MaxBalanceCompliance} from "../src/compliance/MaxBalanceCompliance.sol";
import {MaxHoldersCompliance} from "../src/compliance/MaxHoldersCompliance.sol";
import {TransferLockCompliance} from "../src/compliance/TransferLockCompliance.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";
import {IdentityCloneable} from "../src/IdentityCloneable.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";
import {ClaimTopicsRegistry} from "../src/ClaimTopicsRegistry.sol";

contract ComplianceAggregatorTest is Test {
    ComplianceAggregator public aggregator;
    MaxBalanceCompliance public maxBalanceModule;
    MaxHoldersCompliance public maxHoldersModule;
    TransferLockCompliance public transferLockModule;
    
    TokenCloneable public token1;
    TokenCloneable public token2;
    
    IdentityRegistry public identityRegistry;
    TrustedIssuersRegistry public trustedIssuersRegistry;
    ClaimTopicsRegistry public claimTopicsRegistry;
    
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public issuer;

    uint256 constant MAX_BALANCE = 1000 ether;
    uint256 constant MAX_HOLDERS = 5;
    uint256 constant LOCK_PERIOD = 30 days;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        issuer = makeAddr("issuer");

        // Deploy aggregator
        vm.prank(owner);
        aggregator = new ComplianceAggregator(owner);

        // Setup registries
        vm.startPrank(owner);
        identityRegistry = new IdentityRegistry(owner);
        trustedIssuersRegistry = new TrustedIssuersRegistry(owner);
        claimTopicsRegistry = new ClaimTopicsRegistry(owner);
        
        // Configure registries
        claimTopicsRegistry.addClaimTopic(1); // KYC claim
        
        uint256[] memory claimTopics = new uint256[](1);
        claimTopics[0] = 1;
        trustedIssuersRegistry.addTrustedIssuer(issuer, claimTopics);
        
        vm.stopPrank();
        
        // Register identities
        _registerIdentity(user1);
        _registerIdentity(user2);
        _registerIdentity(user3);
        
        // Deploy tokens
        vm.startPrank(owner);
        token1 = new TokenCloneable();
        token1.initialize("Token 1", "TK1", 18, owner);
        token2 = new TokenCloneable();
        token2.initialize("Token 2", "TK2", 18, owner);
        
        // Set registries for tokens
        token1.setIdentityRegistry(address(identityRegistry));
        token1.setTrustedIssuersRegistry(address(trustedIssuersRegistry));
        token1.setClaimTopicsRegistry(address(claimTopicsRegistry));
        
        token2.setIdentityRegistry(address(identityRegistry));
        token2.setTrustedIssuersRegistry(address(trustedIssuersRegistry));
        token2.setClaimTopicsRegistry(address(claimTopicsRegistry));
        vm.stopPrank();
    }

    function _registerIdentity(address user) internal {
        vm.startPrank(owner);
        IdentityCloneable identity = new IdentityCloneable();
        identity.initialize(user);
        vm.stopPrank();
        
        vm.prank(user);
        identity.addClaim(
            1, // KYC topic
            1, // ECDSA scheme
            issuer,
            hex"", // signature
            hex"", // data
            "" // uri
        );
        
        vm.prank(owner);
        identityRegistry.registerIdentity(user, address(identity));
    }

    // ============ Module Management Tests ============

    function test_AddModule() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        
        aggregator.addModule(address(token1), address(maxBalanceModule));
        vm.stopPrank();

        assertEq(aggregator.getModuleCount(address(token1)), 1);
        assertTrue(aggregator.isModuleActiveForToken(address(token1), address(maxBalanceModule)));
    }

    function test_AddMultipleModules() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxHoldersModule = new MaxHoldersCompliance(owner, MAX_HOLDERS);
        transferLockModule = new TransferLockCompliance(owner, LOCK_PERIOD);
        
        aggregator.addModule(address(token1), address(maxBalanceModule));
        aggregator.addModule(address(token1), address(maxHoldersModule));
        aggregator.addModule(address(token1), address(transferLockModule));
        vm.stopPrank();

        assertEq(aggregator.getModuleCount(address(token1)), 3);
        
        address[] memory modules = aggregator.getModules(address(token1));
        assertEq(modules.length, 3);
        assertEq(modules[0], address(maxBalanceModule));
        assertEq(modules[1], address(maxHoldersModule));
        assertEq(modules[2], address(transferLockModule));
    }

    function test_RemoveModule() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxHoldersModule = new MaxHoldersCompliance(owner, MAX_HOLDERS);
        
        aggregator.addModule(address(token1), address(maxBalanceModule));
        aggregator.addModule(address(token1), address(maxHoldersModule));
        
        aggregator.removeModule(address(token1), address(maxBalanceModule));
        vm.stopPrank();

        assertEq(aggregator.getModuleCount(address(token1)), 1);
        assertFalse(aggregator.isModuleActiveForToken(address(token1), address(maxBalanceModule)));
        assertTrue(aggregator.isModuleActiveForToken(address(token1), address(maxHoldersModule)));
    }

    function test_TokenRegistration() public {
        assertFalse(aggregator.isTokenRegistered(address(token1)));
        
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        aggregator.addModule(address(token1), address(maxBalanceModule));
        vm.stopPrank();

        assertTrue(aggregator.isTokenRegistered(address(token1)));
        assertEq(aggregator.getTokenCount(), 1);
        
        address[] memory tokens = aggregator.getTokens();
        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(token1));
    }

    function test_MultipleTokens() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        MaxBalanceCompliance maxBalanceModule2 = new MaxBalanceCompliance(owner, MAX_BALANCE * 2);
        
        aggregator.addModule(address(token1), address(maxBalanceModule));
        aggregator.addModule(address(token2), address(maxBalanceModule2));
        vm.stopPrank();

        assertEq(aggregator.getTokenCount(), 2);
        assertEq(aggregator.getModuleCount(address(token1)), 1);
        assertEq(aggregator.getModuleCount(address(token2)), 1);
    }

    // ============ Compliance Tests ============

    function test_MaxBalance_WithAggregator() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxBalanceModule.setTokenContract(address(token1));
        
        aggregator.addModule(address(token1), address(maxBalanceModule));
        token1.addComplianceModule(address(aggregator));
        
        // Should allow minting under limit
        token1.mint(user1, 500 ether);
        assertEq(token1.balanceOf(user1), 500 ether);
        
        // Should block minting over limit
        vm.expectRevert("Mint not compliant");
        token1.mint(user1, MAX_BALANCE + 1);
        vm.stopPrank();
    }

    function test_MaxHolders_WithAggregator() public {
        vm.startPrank(owner);
        maxHoldersModule = new MaxHoldersCompliance(owner, 2); // Max 2 holders
        maxHoldersModule.setTokenContract(address(token1));
        maxHoldersModule.addAuthorizedCaller(address(aggregator)); // Authorize aggregator
        
        aggregator.addModule(address(token1), address(maxHoldersModule));
        token1.addComplianceModule(address(aggregator));
        
        // Add 2 holders
        token1.mint(user1, 100 ether);
        token1.mint(user2, 100 ether);
        
        // Should block 3rd holder
        vm.expectRevert("Mint not compliant");
        token1.mint(user3, 100 ether);
        vm.stopPrank();
    }

    function test_TransferLock_WithAggregator() public {
        vm.startPrank(owner);
        transferLockModule = new TransferLockCompliance(owner, LOCK_PERIOD);
        transferLockModule.setTokenContract(address(token1));
        transferLockModule.addAuthorizedCaller(address(aggregator)); // Authorize aggregator
        
        aggregator.addModule(address(token1), address(transferLockModule));
        token1.addComplianceModule(address(aggregator));
        
        token1.mint(user1, 100 ether);
        vm.stopPrank();

        // Should be locked immediately
        vm.prank(user1);
        vm.expectRevert("Transfer not compliant");
        token1.transfer(user2, 50 ether);

        // Should work after lock period
        vm.warp(block.timestamp + LOCK_PERIOD + 1);
        vm.prank(user1);
        token1.transfer(user2, 50 ether);
        
        assertEq(token1.balanceOf(user2), 50 ether);
    }

    function test_CombinedModules() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxBalanceModule.setTokenContract(address(token1));
        
        maxHoldersModule = new MaxHoldersCompliance(owner, MAX_HOLDERS);
        maxHoldersModule.setTokenContract(address(token1));
        maxHoldersModule.addAuthorizedCaller(address(aggregator)); // Authorize aggregator
        
        transferLockModule = new TransferLockCompliance(owner, LOCK_PERIOD);
        transferLockModule.setTokenContract(address(token1));
        transferLockModule.addAuthorizedCaller(address(aggregator)); // Authorize aggregator
        
        aggregator.addModule(address(token1), address(maxBalanceModule));
        aggregator.addModule(address(token1), address(maxHoldersModule));
        aggregator.addModule(address(token1), address(transferLockModule));
        
        token1.addComplianceModule(address(aggregator));
        
        // Should enforce max balance
        vm.expectRevert("Mint not compliant");
        token1.mint(user1, MAX_BALANCE + 1);
        
        // Should work under limit
        token1.mint(user1, 100 ether);
        assertEq(token1.balanceOf(user1), 100 ether);
        vm.stopPrank();
    }

    function test_IndependentTokenModules() public {
        vm.startPrank(owner);
        // Token1: Only max balance
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxBalanceModule.setTokenContract(address(token1));
        aggregator.addModule(address(token1), address(maxBalanceModule));
        token1.addComplianceModule(address(aggregator));
        
        // Token2: Only max holders
        MaxHoldersCompliance maxHoldersModule2 = new MaxHoldersCompliance(owner, 2);
        maxHoldersModule2.setTokenContract(address(token2));
        maxHoldersModule2.addAuthorizedCaller(address(aggregator)); // Authorize aggregator
        aggregator.addModule(address(token2), address(maxHoldersModule2));
        token2.addComplianceModule(address(aggregator));
        
        // Token1 should enforce max balance but not max holders
        token1.mint(user1, MAX_BALANCE);
        token1.mint(user2, MAX_BALANCE);
        token1.mint(user3, MAX_BALANCE); // No holder limit
        
        // Token2 should enforce max holders but not max balance
        token2.mint(user1, MAX_BALANCE * 10); // No balance limit
        token2.mint(user2, MAX_BALANCE * 10);
        
        vm.expectRevert("Mint not compliant");
        token2.mint(user3, 100 ether); // Exceeds holder limit
        vm.stopPrank();
    }

    function test_NoModules_AllowsAll() public {
        vm.prank(owner);
        token1.addComplianceModule(address(aggregator));

        // Without any modules, should allow everything
        vm.prank(owner);
        token1.mint(user1, MAX_BALANCE * 100);
        
        assertEq(token1.balanceOf(user1), MAX_BALANCE * 100);
    }

    function test_DynamicModuleAddition() public {
        vm.startPrank(owner);
        token1.addComplianceModule(address(aggregator));
        
        // Initially no modules, should allow large mint
        token1.mint(user1, MAX_BALANCE * 2);
        assertEq(token1.balanceOf(user1), MAX_BALANCE * 2);
        
        // Add max balance module
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxBalanceModule.setTokenContract(address(token1));
        aggregator.addModule(address(token1), address(maxBalanceModule));
        
        // Now should block large mints
        vm.expectRevert("Mint not compliant");
        token1.mint(user2, MAX_BALANCE * 2);
        vm.stopPrank();
    }

    // ============ Error Cases ============

    function test_RevertWhen_AddModuleNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        aggregator.addModule(address(token1), address(maxBalanceModule));
    }

    function test_RevertWhen_RemoveModuleNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        aggregator.removeModule(address(token1), address(maxBalanceModule));
    }

    function test_RevertWhen_AddModuleTwice() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        
        aggregator.addModule(address(token1), address(maxBalanceModule));
        
        vm.expectRevert("Module already added");
        aggregator.addModule(address(token1), address(maxBalanceModule));
        vm.stopPrank();
    }

    function test_RevertWhen_RemoveInactiveModule() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        
        vm.expectRevert("Module not active");
        aggregator.removeModule(address(token1), address(maxBalanceModule));
        vm.stopPrank();
    }

    function test_RevertWhen_InvalidTokenAddress() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        
        vm.expectRevert("Invalid token address");
        aggregator.addModule(address(0), address(maxBalanceModule));
        vm.stopPrank();
    }

    function test_RevertWhen_InvalidModuleAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid module address");
        aggregator.addModule(address(token1), address(0));
    }

    function test_GetModuleAt() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxHoldersModule = new MaxHoldersCompliance(owner, MAX_HOLDERS);
        
        aggregator.addModule(address(token1), address(maxBalanceModule));
        aggregator.addModule(address(token1), address(maxHoldersModule));
        vm.stopPrank();

        assertEq(aggregator.getModuleAt(address(token1), 0), address(maxBalanceModule));
        assertEq(aggregator.getModuleAt(address(token1), 1), address(maxHoldersModule));
    }

    function test_RevertWhen_GetModuleAtInvalidIndex() public {
        vm.expectRevert("Index out of bounds");
        aggregator.getModuleAt(address(token1), 0);
    }

    // ============ Token Integration Tests ============

    function test_TokenCanAddModuleThroughAggregator() public {
        vm.startPrank(owner);
        // First, add aggregator to token
        token1.addComplianceModule(address(aggregator));
        
        // Deploy a module
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxBalanceModule.setTokenContract(address(token1));
        vm.stopPrank();

        // Token admin can add module through aggregator
        vm.prank(owner);
        token1.addModuleThroughAggregator(address(aggregator), address(maxBalanceModule));

        // Verify module was added
        assertEq(aggregator.getModuleCount(address(token1)), 1);
        assertTrue(aggregator.isModuleActiveForToken(address(token1), address(maxBalanceModule)));
    }

    function test_TokenCanRemoveModuleThroughAggregator() public {
        vm.startPrank(owner);
        token1.addComplianceModule(address(aggregator));
        
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxBalanceModule.setTokenContract(address(token1));
        
        token1.addModuleThroughAggregator(address(aggregator), address(maxBalanceModule));
        assertEq(aggregator.getModuleCount(address(token1)), 1);
        
        // Remove module through token
        token1.removeModuleThroughAggregator(address(aggregator), address(maxBalanceModule));
        vm.stopPrank();

        // Verify module was removed
        assertEq(aggregator.getModuleCount(address(token1)), 0);
        assertFalse(aggregator.isModuleActiveForToken(address(token1), address(maxBalanceModule)));
    }

    function test_TokenCanQueryAggregatorModules() public {
        vm.startPrank(owner);
        token1.addComplianceModule(address(aggregator));
        
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxBalanceModule.setTokenContract(address(token1));
        
        maxHoldersModule = new MaxHoldersCompliance(owner, MAX_HOLDERS);
        maxHoldersModule.setTokenContract(address(token1));
        maxHoldersModule.addAuthorizedCaller(address(aggregator));
        
        token1.addModuleThroughAggregator(address(aggregator), address(maxBalanceModule));
        token1.addModuleThroughAggregator(address(aggregator), address(maxHoldersModule));
        vm.stopPrank();

        // Query modules through token
        address[] memory modules = token1.getAggregatorModules(address(aggregator));
        assertEq(modules.length, 2);
        assertEq(modules[0], address(maxBalanceModule));
        assertEq(modules[1], address(maxHoldersModule));

        // Query module count
        uint256 count = token1.getAggregatorModuleCount(address(aggregator));
        assertEq(count, 2);

        // Check if module is active
        assertTrue(token1.isModuleActiveInAggregator(address(aggregator), address(maxBalanceModule)));
        assertTrue(token1.isModuleActiveInAggregator(address(aggregator), address(maxHoldersModule)));
    }

    function test_RevertWhen_AddModuleThroughAggregatorNotAdded() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        
        // Try to add module without adding aggregator first
        vm.expectRevert("Aggregator not added as compliance module");
        token1.addModuleThroughAggregator(address(aggregator), address(maxBalanceModule));
        vm.stopPrank();
    }

    function test_TokenAndOwnerCanBothManageModules() public {
        vm.startPrank(owner);
        token1.addComplianceModule(address(aggregator));
        
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxBalanceModule.setTokenContract(address(token1));
        
        maxHoldersModule = new MaxHoldersCompliance(owner, MAX_HOLDERS);
        maxHoldersModule.setTokenContract(address(token1));
        maxHoldersModule.addAuthorizedCaller(address(aggregator));
        vm.stopPrank();

        // Owner can add module directly to aggregator
        vm.prank(owner);
        aggregator.addModule(address(token1), address(maxBalanceModule));

        // Token admin can also add module through token
        vm.prank(owner);
        token1.addModuleThroughAggregator(address(aggregator), address(maxHoldersModule));

        // Both modules should be active
        assertEq(aggregator.getModuleCount(address(token1)), 2);
    }
}
