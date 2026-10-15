// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ComplianceAggregator} from "../src/compliance/ComplianceAggregator.sol";
import {MaxBalanceCompliance} from "../src/compliance/MaxBalanceCompliance.sol";
import {MaxHoldersCompliance} from "../src/compliance/MaxHoldersCompliance.sol";
import {TransferLockCompliance} from "../src/compliance/TransferLockCompliance.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";
import {TokenCloneFactory} from "../src/TokenCloneFactory.sol";
import {IdentityCloneable} from "../src/IdentityCloneable.sol";
import {IdentityCloneFactory} from "../src/IdentityCloneFactory.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";
import {ClaimTopicsRegistry} from "../src/ClaimTopicsRegistry.sol";
import {SigUtils} from "./helpers/SigUtils.sol";

contract ComplianceAggregatorTest is Test {
    ComplianceAggregator public aggregator;
    MaxBalanceCompliance public maxBalanceModule;
    MaxHoldersCompliance public maxHoldersModule;
    TransferLockCompliance public transferLockModule;

    TokenCloneable public token1;
    TokenCloneable public token2;
    TokenCloneFactory public tokenFactory;
    IdentityCloneFactory public identityFactory;

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

    uint256 internal constant ISSUER_PK = 0xB0B;
    uint256 internal constant EXPIRES_AT = 2_000_000_000;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        issuer = vm.addr(ISSUER_PK);

        // Deploy aggregator
        vm.prank(owner);
        aggregator = new ComplianceAggregator(owner);

        // Deploy clone factories (patrón de producción: implementación + clon + initialize)
        tokenFactory = new TokenCloneFactory(owner);
        identityFactory = new IdentityCloneFactory(owner);

        // H-07: las factories ya no son permissionless; el test se autoriza como creador.
        vm.startPrank(owner);
        tokenFactory.setAuthorizedCreator(address(this), true);
        identityFactory.setAuthorizedCreator(address(this), true);
        vm.stopPrank();

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

        // Deploy tokens as initialized clones through the factory
        vm.startPrank(owner);
        token1 = TokenCloneable(tokenFactory.createToken("Token 1", "TK1", 18, owner));
        token2 = TokenCloneable(tokenFactory.createToken("Token 2", "TK2", 18, owner));

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
        // Clon inicializado con owner = user (patrón de producción)
        IdentityCloneable identity = IdentityCloneable(identityFactory.createIdentity(user));

        bytes memory data = abi.encode("KYC", user);
        bytes memory signature = SigUtils.signClaim(ISSUER_PK, address(identity), user, 1, 1, data, EXPIRES_AT);

        vm.prank(user);
        identity.addClaim(
            1, // KYC topic
            1, // ECDSA scheme
            issuer,
            signature, // firma EIP-712 valida (RF-001)
            data, // claim data
            "", // uri
            EXPIRES_AT
        );

        vm.prank(owner);
        identityRegistry.registerIdentity(user, address(identity));
    }

    // ============ Helpers de la ruta de produccion (RF-012 / CU-16) ============

    /// @dev RF-012 (Ciclo 7): ruta de produccion para administrar modulos. El aggregator debe estar
    /// dado de alta como modulo de compliance del token; despues es el propio token, a traves de
    /// `COMPLIANCE_ROLE`, quien llama al aggregator, porque `addModule`/`removeModule` solo aceptan
    /// al token (`onlyToken`).
    function _registerAggregatorOnToken(TokenCloneable token) internal {
        token.addComplianceModule(address(aggregator));
    }

    function _addModuleViaToken(TokenCloneable token, address module) internal {
        token.addModuleThroughAggregator(address(aggregator), module);
    }

    function _removeModuleViaToken(TokenCloneable token, address module) internal {
        token.removeModuleThroughAggregator(address(aggregator), module);
    }

    // ============ Module Management Tests ============

    function test_AddModule() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxBalanceModule.setTokenContract(address(token1));

        _registerAggregatorOnToken(token1);
        _addModuleViaToken(token1, address(maxBalanceModule));
        vm.stopPrank();

        assertEq(aggregator.getModuleCount(address(token1)), 1);
        assertTrue(aggregator.isModuleActiveForToken(address(token1), address(maxBalanceModule)));
    }

    function test_AddMultipleModules() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxBalanceModule.setTokenContract(address(token1));
        maxHoldersModule = new MaxHoldersCompliance(owner, MAX_HOLDERS);
        maxHoldersModule.setTokenContract(address(token1));
        transferLockModule = new TransferLockCompliance(owner, LOCK_PERIOD);
        transferLockModule.setTokenContract(address(token1));

        _registerAggregatorOnToken(token1);
        _addModuleViaToken(token1, address(maxBalanceModule));
        _addModuleViaToken(token1, address(maxHoldersModule));
        _addModuleViaToken(token1, address(transferLockModule));
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
        maxBalanceModule.setTokenContract(address(token1));
        maxHoldersModule = new MaxHoldersCompliance(owner, MAX_HOLDERS);
        maxHoldersModule.setTokenContract(address(token1));

        _registerAggregatorOnToken(token1);
        _addModuleViaToken(token1, address(maxBalanceModule));
        _addModuleViaToken(token1, address(maxHoldersModule));

        _removeModuleViaToken(token1, address(maxBalanceModule));
        vm.stopPrank();

        assertEq(aggregator.getModuleCount(address(token1)), 1);
        assertFalse(aggregator.isModuleActiveForToken(address(token1), address(maxBalanceModule)));
        assertTrue(aggregator.isModuleActiveForToken(address(token1), address(maxHoldersModule)));
    }

    function test_TokenRegistration() public {
        assertFalse(aggregator.isTokenRegistered(address(token1)));

        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxBalanceModule.setTokenContract(address(token1));
        _registerAggregatorOnToken(token1);
        _addModuleViaToken(token1, address(maxBalanceModule));
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
        maxBalanceModule.setTokenContract(address(token1));
        MaxBalanceCompliance maxBalanceModule2 = new MaxBalanceCompliance(owner, MAX_BALANCE * 2);
        maxBalanceModule2.setTokenContract(address(token2));

        _registerAggregatorOnToken(token1);
        _registerAggregatorOnToken(token2);
        _addModuleViaToken(token1, address(maxBalanceModule));
        _addModuleViaToken(token2, address(maxBalanceModule2));
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

        _registerAggregatorOnToken(token1);
        _addModuleViaToken(token1, address(maxBalanceModule));

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

        _registerAggregatorOnToken(token1);
        _addModuleViaToken(token1, address(maxHoldersModule));

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

        _registerAggregatorOnToken(token1);
        _addModuleViaToken(token1, address(transferLockModule));

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

        _registerAggregatorOnToken(token1);
        _addModuleViaToken(token1, address(maxBalanceModule));
        _addModuleViaToken(token1, address(maxHoldersModule));
        _addModuleViaToken(token1, address(transferLockModule));

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
        _registerAggregatorOnToken(token1);
        _addModuleViaToken(token1, address(maxBalanceModule));

        // Token2: Only max holders
        MaxHoldersCompliance maxHoldersModule2 = new MaxHoldersCompliance(owner, 2);
        maxHoldersModule2.setTokenContract(address(token2));
        maxHoldersModule2.addAuthorizedCaller(address(aggregator)); // Authorize aggregator
        _registerAggregatorOnToken(token2);
        _addModuleViaToken(token2, address(maxHoldersModule2));

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

    /// @dev RF-012 (CU-16, fail-closed): con el aggregator dado de alta pero **sin modulos** ya no se
    /// permite todo; el mint revierte ("Mint not compliant"). Antes este caso era `test_NoModules_AllowsAll`
    /// (fail-open H-22). Se conserva el montaje y la asercion se invierte a la nueva semantica.
    function test_NoModules_FailClosed() public {
        vm.startPrank(owner);
        token1.addComplianceModule(address(aggregator));

        // Without any modules, the aggregator is fail-closed: nothing is allowed.
        vm.expectRevert("Mint not compliant");
        token1.mint(user1, MAX_BALANCE * 100);
        vm.stopPrank();

        assertEq(token1.balanceOf(user1), 0, "fail-closed: sin modulos no se acuna nada");
    }

    function test_DynamicModuleAddition() public {
        vm.startPrank(owner);
        token1.addComplianceModule(address(aggregator));

        // RF-012: inicialmente no hay modulos → fail-closed, el mint grande se bloquea.
        vm.expectRevert("Mint not compliant");
        token1.mint(user1, MAX_BALANCE * 2);

        // Add a permissive max balance module: the large mint now succeeds.
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE * 2);
        maxBalanceModule.setTokenContract(address(token1));
        _addModuleViaToken(token1, address(maxBalanceModule));

        token1.mint(user1, MAX_BALANCE * 2);
        assertEq(token1.balanceOf(user1), MAX_BALANCE * 2);

        // Add a stricter module: large mints are blocked again.
        MaxBalanceCompliance strictModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        strictModule.setTokenContract(address(token1));
        _addModuleViaToken(token1, address(strictModule));

        vm.expectRevert("Mint not compliant");
        token1.mint(user2, MAX_BALANCE * 2);
        vm.stopPrank();
    }

    // ============ Error Cases ============

    /// @dev RF-012: la autorizacion corre antes que el resto; solo el propio token puede entrar.
    function test_RevertWhen_AddModuleNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Only token admin can call");
        aggregator.addModule(address(token1), address(maxBalanceModule));
    }

    function test_RevertWhen_RemoveModuleNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Only token admin can call");
        aggregator.removeModule(address(token1), address(maxBalanceModule));
    }

    function test_RevertWhen_AddModuleTwice() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxBalanceModule.setTokenContract(address(token1));

        _registerAggregatorOnToken(token1);
        _addModuleViaToken(token1, address(maxBalanceModule));

        vm.expectRevert("Module already added");
        _addModuleViaToken(token1, address(maxBalanceModule));
        vm.stopPrank();
    }

    function test_RevertWhen_RemoveInactiveModule() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxBalanceModule.setTokenContract(address(token1));

        // AF-13: el aggregator debe estar dado de alta para alcanzar la comprobacion del token.
        _registerAggregatorOnToken(token1);

        vm.expectRevert("Module not active for this token");
        _removeModuleViaToken(token1, address(maxBalanceModule));
        vm.stopPrank();
    }

    /// @dev RF-012: `onlyToken` se evalua antes que `require(token != address(0))`, asi que una llamada
    /// externa con `token == address(0)` se rechaza por autorizacion y nunca registra nada. La
    /// comprobacion de direccion cero del aggregator queda inalcanzable desde llamadores externos
    /// (documentado como D-043).
    function test_RevertWhen_InvalidTokenAddress() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);

        vm.expectRevert("Only token admin can call");
        aggregator.addModule(address(0), address(maxBalanceModule));
        vm.stopPrank();

        assertEq(aggregator.getModuleCount(address(0)), 0);
        assertFalse(aggregator.isTokenRegistered(address(0)));
    }

    /// @dev RF-012: la ruta de produccion conserva el rechazo de modulo cero en el propio token.
    function test_RevertWhen_InvalidModuleAddress() public {
        vm.startPrank(owner);
        _registerAggregatorOnToken(token1);

        vm.expectRevert("Invalid module address");
        token1.addModuleThroughAggregator(address(aggregator), address(0));
        vm.stopPrank();
    }

    function test_GetModuleAt() public {
        vm.startPrank(owner);
        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxBalanceModule.setTokenContract(address(token1));
        maxHoldersModule = new MaxHoldersCompliance(owner, MAX_HOLDERS);
        maxHoldersModule.setTokenContract(address(token1));

        _registerAggregatorOnToken(token1);
        _addModuleViaToken(token1, address(maxBalanceModule));
        _addModuleViaToken(token1, address(maxHoldersModule));
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

    /// @dev RF-012 (CU-16): modelo nuevo de administracion. El token (via `COMPLIANCE_ROLE`) si puede
    /// administrar sus modulos; el owner global del aggregator **no**, porque no es el token y
    /// `onlyToken` lo rechaza con "Only token admin can call". Sustituye a
    /// `test_TokenAndOwnerCanBothManageModules`, conservando el montaje de los dos modulos.
    function test_TokenCanManageModules_OwnerCannot() public {
        vm.startPrank(owner);
        token1.addComplianceModule(address(aggregator));

        maxBalanceModule = new MaxBalanceCompliance(owner, MAX_BALANCE);
        maxBalanceModule.setTokenContract(address(token1));

        maxHoldersModule = new MaxHoldersCompliance(owner, MAX_HOLDERS);
        maxHoldersModule.setTokenContract(address(token1));
        maxHoldersModule.addAuthorizedCaller(address(aggregator));

        // Token admin can add module through token
        token1.addModuleThroughAggregator(address(aggregator), address(maxBalanceModule));
        assertEq(aggregator.getModuleCount(address(token1)), 1);

        // Owner global del aggregator: la ruta directa ya no esta permitida.
        vm.expectRevert("Only token admin can call");
        aggregator.addModule(address(token1), address(maxHoldersModule));
        vm.stopPrank();

        // Solo el modulo anadido por el token queda activo.
        assertEq(aggregator.getModuleCount(address(token1)), 1);
        assertTrue(aggregator.isModuleActiveForToken(address(token1), address(maxBalanceModule)));
        assertFalse(aggregator.isModuleActiveForToken(address(token1), address(maxHoldersModule)));
    }
}
