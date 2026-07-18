// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";
import {IdentityCloneable} from "../src/IdentityCloneable.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";
import {ClaimTopicsRegistry} from "../src/ClaimTopicsRegistry.sol";
import {MaxBalanceCompliance} from "../src/compliance/MaxBalanceCompliance.sol";
import {MaxHoldersCompliance} from "../src/compliance/MaxHoldersCompliance.sol";
import {TransferLockCompliance} from "../src/compliance/TransferLockCompliance.sol";

contract TokenTest is Test {
    TokenCloneable public token;
    IdentityRegistry public identityRegistry;
    TrustedIssuersRegistry public trustedIssuersRegistry;
    ClaimTopicsRegistry public claimTopicsRegistry;

    MaxBalanceCompliance public maxBalanceCompliance;
    MaxHoldersCompliance public maxHoldersCompliance;
    TransferLockCompliance public transferLockCompliance;

    address public admin;
    address public issuer;
    address public user1;
    address public user2;
    address public user3;

    IdentityCloneable public identity1;
    IdentityCloneable public identity2;
    IdentityCloneable public identity3;

    uint256 constant KYC_TOPIC = 1;
    uint256 constant AML_TOPIC = 2;
    uint256 constant MAX_BALANCE = 1000 * 10**18;
    uint256 constant MAX_HOLDERS = 10;
    uint256 constant LOCK_PERIOD = 30 days;

    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    function setUp() public {
        admin = address(this);
        issuer = makeAddr("issuer");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Deploy token
        token = new TokenCloneable();
        token.initialize("Security Token", "SEC", 18, admin);

        // Deploy registries
        identityRegistry = new IdentityRegistry(admin);
        trustedIssuersRegistry = new TrustedIssuersRegistry(admin);
        claimTopicsRegistry = new ClaimTopicsRegistry(admin);

        // Deploy compliance modules
        maxBalanceCompliance = new MaxBalanceCompliance(admin, MAX_BALANCE);
        maxHoldersCompliance = new MaxHoldersCompliance(admin, MAX_HOLDERS);
        transferLockCompliance = new TransferLockCompliance(admin, LOCK_PERIOD);

        // Setup token with registries
        token.setIdentityRegistry(address(identityRegistry));
        token.setTrustedIssuersRegistry(address(trustedIssuersRegistry));
        token.setClaimTopicsRegistry(address(claimTopicsRegistry));

        // Setup compliance modules
        maxBalanceCompliance.setTokenContract(address(token));
        maxHoldersCompliance.setTokenContract(address(token));
        transferLockCompliance.setTokenContract(address(token));

        token.addComplianceModule(address(maxBalanceCompliance));
        token.addComplianceModule(address(maxHoldersCompliance));
        token.addComplianceModule(address(transferLockCompliance));

        // Setup trusted issuer and claim topics
        uint256[] memory topics = new uint256[](2);
        topics[0] = KYC_TOPIC;
        topics[1] = AML_TOPIC;
        trustedIssuersRegistry.addTrustedIssuer(issuer, topics);

        claimTopicsRegistry.addClaimTopic(KYC_TOPIC);
        claimTopicsRegistry.addClaimTopic(AML_TOPIC);

        // Create identities for users
        identity1 = new IdentityCloneable();
        identity1.initialize(admin);
        identity2 = new IdentityCloneable();
        identity2.initialize(admin);
        identity3 = new IdentityCloneable();
        identity3.initialize(admin);

        // Register identities
        identityRegistry.registerIdentity(user1, address(identity1));
        identityRegistry.registerIdentity(user2, address(identity2));
        identityRegistry.registerIdentity(user3, address(identity3));

        // Add claims to identities
        _addClaims(identity1);
        _addClaims(identity2);
        _addClaims(identity3);
    }

    function _addClaims(IdentityCloneable identity) internal {
        identity.addClaim(KYC_TOPIC, 1, issuer, "", "", "");
        identity.addClaim(AML_TOPIC, 1, issuer, "", "", "");
    }

    function test_Constructor() public {
        assertEq(token.name(), "Security Token");
        assertEq(token.symbol(), "SEC");
        assertEq(token.decimals(), 18);
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(AGENT_ROLE, admin));
        assertTrue(token.hasRole(COMPLIANCE_ROLE, admin));
    }

    function test_SetRegistries() public {
        TokenCloneable newToken = new TokenCloneable();
        newToken.initialize("Test", "TST", 18, admin);

        newToken.setIdentityRegistry(address(identityRegistry));
        newToken.setTrustedIssuersRegistry(address(trustedIssuersRegistry));
        newToken.setClaimTopicsRegistry(address(claimTopicsRegistry));

        assertEq(address(newToken.identityRegistry()), address(identityRegistry));
        assertEq(address(newToken.trustedIssuersRegistry()), address(trustedIssuersRegistry));
        assertEq(address(newToken.claimTopicsRegistry()), address(claimTopicsRegistry));
    }

    function test_RevertWhen_SetRegistriesNotAdmin() public {
        vm.startPrank(user1);

        vm.expectRevert();
        token.setIdentityRegistry(address(identityRegistry));

        vm.expectRevert();
        token.setTrustedIssuersRegistry(address(trustedIssuersRegistry));

        vm.expectRevert();
        token.setClaimTopicsRegistry(address(claimTopicsRegistry));

        vm.stopPrank();
    }

    function test_AddComplianceModule() public {
        TokenCloneable newToken = new TokenCloneable();
        newToken.initialize("Test", "TST", 18, admin);
        MaxBalanceCompliance compliance = new MaxBalanceCompliance(admin, MAX_BALANCE);

        newToken.addComplianceModule(address(compliance));

        address[] memory modules = newToken.getComplianceModules();
        assertEq(modules.length, 1);
        assertEq(modules[0], address(compliance));
    }

    function test_RemoveComplianceModule() public {
        address[] memory modulesBefore = token.getComplianceModules();
        uint256 countBefore = modulesBefore.length;

        token.removeComplianceModule(0);

        address[] memory modulesAfter = token.getComplianceModules();
        assertEq(modulesAfter.length, countBefore - 1);
    }

    function test_IsVerified() public {
        assertTrue(token.isVerified(user1));
        assertTrue(token.isVerified(user2));
        assertTrue(token.isVerified(user3));
    }

    function test_IsVerified_FailsWhenNotRegistered() public {
        address unregistered = makeAddr("unregistered");
        assertFalse(token.isVerified(unregistered));
    }

    function test_IsVerified_FailsWhenMissingClaim() public {
        // Create user without all required claims
        address user4 = makeAddr("user4");
        IdentityCloneable identity4 = new IdentityCloneable();
        identity4.initialize(admin);
        identityRegistry.registerIdentity(user4, address(identity4));

        // Add only KYC claim, missing AML
        identity4.addClaim(KYC_TOPIC, 1, issuer, "", "", "");

        assertFalse(token.isVerified(user4));
    }

    function test_Mint() public {
        uint256 amount = 100 * 10**18;

        token.mint(user1, amount);

        assertEq(token.balanceOf(user1), amount);
    }

    function test_RevertWhen_MintToUnverified() public {
        address unverified = makeAddr("unverified");

        vm.expectRevert("Recipient not verified");
        token.mint(unverified, 100 * 10**18);
    }

    function test_RevertWhen_MintNotAgent() public {
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user2, 100 * 10**18);
    }

    function test_Burn() public {
        uint256 amount = 100 * 10**18;
        token.mint(user1, amount);

        token.burn(user1, amount);

        assertEq(token.balanceOf(user1), 0);
    }

    function test_RevertWhen_BurnNotAgent() public {
        vm.prank(user1);
        vm.expectRevert();
        token.burn(user2, 100 * 10**18);
    }

    function test_Transfer_Success() public {
        uint256 amount = 100 * 10**18;
        token.mint(user1, amount);

        // Wait for lock period to expire
        vm.warp(block.timestamp + LOCK_PERIOD + 1);

        vm.prank(user1);
        bool success = token.transfer(user2, 50 * 10**18);
        assertTrue(success);

        assertEq(token.balanceOf(user1), 50 * 10**18);
        assertEq(token.balanceOf(user2), 50 * 10**18);
    }

    function test_Transfer_FailsWhenLocked() public {
        uint256 amount = 100 * 10**18;
        token.mint(user1, amount);

        // Try to transfer before lock expires
        vm.prank(user1);
        vm.expectRevert("Transfer not compliant");
        bool success = token.transfer(user2, 50 * 10**18);
        assertFalse(success);
    }

    function test_Transfer_FailsWhenExceedsMaxBalance() public {
        token.mint(user1, MAX_BALANCE);
        token.mint(user2, 500 * 10**18);

        // Wait for lock period
        vm.warp(block.timestamp + LOCK_PERIOD + 1);

        // Try to transfer amount that would exceed max balance
        vm.prank(user1);
        vm.expectRevert("Transfer not compliant");
        bool success = token.transfer(user2, 600 * 10**18);
        assertFalse(success);
    }

    function test_FreezeAccount() public {
        token.freezeAccount(user1);
        assertTrue(token.isFrozen(user1));
    }

    function test_UnfreezeAccount() public {
        token.freezeAccount(user1);
        token.unfreezeAccount(user1);
        assertFalse(token.isFrozen(user1));
    }

    function test_Transfer_FailsWhenFrozen() public {
        uint256 amount = 100 * 10**18;
        token.mint(user1, amount);

        // Freeze user1
        token.freezeAccount(user1);

        // Wait for lock period
        vm.warp(block.timestamp + LOCK_PERIOD + 1);

        // Try to transfer
        vm.prank(user1);
        vm.expectRevert("Transfer not compliant");
        bool success = token.transfer(user2, 50 * 10**18);
        assertFalse(success);
    }

    function test_Pause() public {
        token.pause();
        assertTrue(token.paused());
    }

    function test_Unpause() public {
        token.pause();
        token.unpause();
        assertFalse(token.paused());
    }

    function test_Transfer_FailsWhenPaused() public {
        uint256 amount = 100 * 10**18;
        token.mint(user1, amount);

        // Pause token
        token.pause();

        // Wait for lock period
        vm.warp(block.timestamp + LOCK_PERIOD + 1);

        // Try to transfer
        vm.prank(user1);
        vm.expectRevert("Transfer not compliant");
        bool success = token.transfer(user2, 50 * 10**18);
        assertFalse(success);
    }

    function test_ForcedTransfer() public {
        uint256 amount = 100 * 10**18;
        token.mint(user1, amount);

        // Agent can force transfer even during lock period
        token.forcedTransfer(user1, user2, 50 * 10**18);

        assertEq(token.balanceOf(user1), 50 * 10**18);
        assertEq(token.balanceOf(user2), 50 * 10**18);
    }

    function test_ForcedTransfer_BypassesCompliance() public {
        // Mint max balance to user2
        token.mint(user2, MAX_BALANCE);

        // Mint to user1
        token.mint(user1, 500 * 10**18);

        // Agent can force transfer even though it would exceed max balance
        token.forcedTransfer(user1, user2, 100 * 10**18);

        assertGt(token.balanceOf(user2), MAX_BALANCE);
    }

    function test_RevertWhen_ForcedTransferToUnverified() public {
        uint256 amount = 100 * 10**18;
        token.mint(user1, amount);

        address unverified = makeAddr("unverified");

        vm.expectRevert("Recipient not verified");
        token.forcedTransfer(user1, unverified, 50 * 10**18);
    }

    function test_RevertWhen_ForcedTransferNotAgent() public {
        vm.prank(user1);
        vm.expectRevert();
        token.forcedTransfer(user2, user3, 50 * 10**18);
    }

    function test_CanTransfer() public {
        token.mint(user1, 100 * 10**18);

        // Cannot transfer during lock
        assertFalse(token.canTransfer(user1, user2, 50 * 10**18));

        // Wait for lock period
        vm.warp(block.timestamp + LOCK_PERIOD + 1);

        // Can transfer after lock
        assertTrue(token.canTransfer(user1, user2, 50 * 10**18));
    }

    function test_GetComplianceModules() public {
        address[] memory modules = token.getComplianceModules();
        assertEq(modules.length, 3);
        assertEq(modules[0], address(maxBalanceCompliance));
        assertEq(modules[1], address(maxHoldersCompliance));
        assertEq(modules[2], address(transferLockCompliance));
    }

    function testFuzz_MintAndBurn(uint256 amount) public {
        amount = bound(amount, 1, MAX_BALANCE);

        token.mint(user1, amount);
        assertEq(token.balanceOf(user1), amount);

        token.burn(user1, amount);
        assertEq(token.balanceOf(user1), 0);
    }

    function test_CompleteTransferFlow() public {
        // 1. Mint tokens to user1
        uint256 initialAmount = 500 * 10**18;
        token.mint(user1, initialAmount);
        assertEq(token.balanceOf(user1), initialAmount);

        // 2. Verify lock is active
        assertTrue(transferLockCompliance.isLocked(user1));
        assertFalse(token.canTransfer(user1, user2, 100 * 10**18));

        // 3. Wait for lock period
        vm.warp(block.timestamp + LOCK_PERIOD + 1);

        // 4. Verify can now transfer
        assertTrue(token.canTransfer(user1, user2, 100 * 10**18));

        // 5. Execute transfer
        vm.prank(user1);
        bool success = token.transfer(user2, 100 * 10**18);
        assertTrue(success);

        // 6. Verify balances
        assertEq(token.balanceOf(user1), 400 * 10**18);
        assertEq(token.balanceOf(user2), 100 * 10**18);

        // 7. Verify user2 is now locked
        assertTrue(transferLockCompliance.isLocked(user2));
    }
}
