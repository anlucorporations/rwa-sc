// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ClaimTopicsRegistryCloneable} from "../src/ClaimTopicsRegistryCloneable.sol";
import {ClaimTopicsRegistryCloneFactory} from "../src/ClaimTopicsRegistryCloneFactory.sol";

contract ClaimTopicsRegistryCloneFactoryTest is Test {
    ClaimTopicsRegistryCloneFactory public factory;
    address public owner;
    address public tokenA;
    address public tokenB;

    function setUp() public {
        owner = makeAddr("owner");
        tokenA = makeAddr("tokenA");
        tokenB = makeAddr("tokenB");

        vm.prank(owner);
        factory = new ClaimTopicsRegistryCloneFactory(owner);
    }

    function test_CreateRegistry() public {
        address admin = makeAddr("admin");

        address registry = factory.createRegistry(admin);

        assertTrue(registry != address(0));
        assertEq(ClaimTopicsRegistryCloneable(registry).owner(), admin);
        assertEq(factory.getTotalRegistries(), 1);
    }

    function test_CreateRegistryForToken() public {
        address admin = makeAddr("admin");

        address registry = factory.createRegistryForToken(admin, tokenA);

        assertTrue(registry != address(0));
        assertEq(factory.getRegistryForToken(tokenA), registry);
        assertEq(ClaimTopicsRegistryCloneable(registry).owner(), admin);
    }

    function test_CreateRegistryWithTopics() public {
        address admin = makeAddr("admin");
        uint256[] memory topics = new uint256[](3);
        topics[0] = 1; // KYC
        topics[1] = 2; // AML
        topics[2] = 3; // Accredited Investor

        address registry = factory.createRegistryWithTopics(admin, topics);

        ClaimTopicsRegistryCloneable registryContract = ClaimTopicsRegistryCloneable(registry);
        assertEq(registryContract.getClaimTopicsCount(), 3);
        assertTrue(registryContract.claimTopicExists(1));
        assertTrue(registryContract.claimTopicExists(2));
        assertTrue(registryContract.claimTopicExists(3));
    }

    function test_CreateMultipleRegistriesForDifferentTokens() public {
        address admin = makeAddr("admin");

        // Registry for Token A (strict requirements)
        uint256[] memory strictTopics = new uint256[](4);
        strictTopics[0] = 1; // KYC
        strictTopics[1] = 2; // AML
        strictTopics[2] = 3; // Accredited Investor
        strictTopics[3] = 4; // Tax Compliance

        address registryA = factory.createRegistryForTokenWithTopics(admin, tokenA, strictTopics);

        // Registry for Token B (light requirements)
        uint256[] memory lightTopics = new uint256[](1);
        lightTopics[0] = 1; // Only KYC

        address registryB = factory.createRegistryForTokenWithTopics(admin, tokenB, lightTopics);

        // Verify Token A requirements
        ClaimTopicsRegistryCloneable registryAContract = ClaimTopicsRegistryCloneable(registryA);
        assertEq(registryAContract.getClaimTopicsCount(), 4);

        // Verify Token B requirements
        ClaimTopicsRegistryCloneable registryBContract = ClaimTopicsRegistryCloneable(registryB);
        assertEq(registryBContract.getClaimTopicsCount(), 1);

        // Verify mapping
        assertEq(factory.getRegistryForToken(tokenA), registryA);
        assertEq(factory.getRegistryForToken(tokenB), registryB);
    }

    function test_OwnerCanModifyTopics() public {
        address admin = makeAddr("admin");
        address registry = factory.createRegistry(admin);

        ClaimTopicsRegistryCloneable registryContract = ClaimTopicsRegistryCloneable(registry);

        // Admin can add topics
        vm.startPrank(admin);
        registryContract.addClaimTopic(1);
        registryContract.addClaimTopic(2);
        vm.stopPrank();

        assertEq(registryContract.getClaimTopicsCount(), 2);

        // Admin can remove topics
        vm.prank(admin);
        registryContract.removeClaimTopic(1);

        assertEq(registryContract.getClaimTopicsCount(), 1);
        assertFalse(registryContract.claimTopicExists(1));
        assertTrue(registryContract.claimTopicExists(2));
    }

    function test_GetRegistriesByOwner() public {
        address admin = makeAddr("admin");

        factory.createRegistry(admin);
        factory.createRegistry(admin);
        factory.createRegistry(admin);

        address[] memory registries = factory.getRegistriesByOwner(admin);
        assertEq(registries.length, 3);
    }

    function test_RevertWhen_CreateDuplicateTokenRegistry() public {
        address admin = makeAddr("admin");

        factory.createRegistryForToken(admin, tokenA);

        vm.expectRevert("Token already has a registry");
        factory.createRegistryForToken(admin, tokenA);
    }

    function test_RevertWhen_InvalidOwner() public {
        vm.expectRevert("Invalid owner address");
        factory.createRegistry(address(0));
    }

    function test_RevertWhen_InvalidToken() public {
        address admin = makeAddr("admin");

        vm.expectRevert("Invalid token address");
        factory.createRegistryForToken(admin, address(0));
    }

    function test_GasSavings() public {
        // Compare gas costs
        uint256 gasStart;
        uint256 gasUsed;

        // Deploy full contract
        gasStart = gasleft();
        new ClaimTopicsRegistryCloneable();
        uint256 fullDeployGas = gasStart - gasleft();

        // Deploy clone
        address admin = makeAddr("admin");
        gasStart = gasleft();
        factory.createRegistry(admin);
        gasUsed = gasStart - gasleft();

        // Clone should use significantly less gas
        assertTrue(gasUsed < fullDeployGas / 2, "Clone should save at least 50% gas");
    }

    function test_DynamicTopicsScenario() public {
        address admin = makeAddr("admin");
        
        // Day 1: Create registry with basic requirements
        uint256[] memory basicTopics = new uint256[](1);
        basicTopics[0] = 1; // KYC only
        
        address registry = factory.createRegistryForTokenWithTopics(admin, tokenA, basicTopics);
        ClaimTopicsRegistryCloneable registryContract = ClaimTopicsRegistryCloneable(registry);
        
        assertEq(registryContract.getClaimTopicsCount(), 1);
        
        // Day 180: Add AML requirement
        vm.prank(admin);
        registryContract.addClaimTopic(2); // AML
        
        assertEq(registryContract.getClaimTopicsCount(), 2);
        assertTrue(registryContract.claimTopicExists(2));
        
        // Day 365: Add Accredited Investor requirement
        vm.prank(admin);
        registryContract.addClaimTopic(3);
        
        assertEq(registryContract.getClaimTopicsCount(), 3);
        
        // Day 400: Remove AML (relaxing requirements)
        vm.prank(admin);
        registryContract.removeClaimTopic(2);
        
        assertEq(registryContract.getClaimTopicsCount(), 2);
        assertFalse(registryContract.claimTopicExists(2));
        assertTrue(registryContract.claimTopicExists(1)); // KYC still required
        assertTrue(registryContract.claimTopicExists(3)); // Accredited Investor still required
    }

    function test_GetGasSavingsInfo() public view {
        string memory info = factory.getGasSavingsInfo();
        assertTrue(bytes(info).length > 0);
    }
}

