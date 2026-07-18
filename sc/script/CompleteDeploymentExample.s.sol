// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenCloneFactory} from "../src/TokenCloneFactory.sol";
import {IdentityCloneFactory} from "../src/IdentityCloneFactory.sol";
import {ClaimTopicsRegistryCloneFactory} from "../src/ClaimTopicsRegistryCloneFactory.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";
import {IdentityCloneable} from "../src/IdentityCloneable.sol";
import {ClaimTopicsRegistryCloneable} from "../src/ClaimTopicsRegistryCloneable.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";

/**
 * @title CompleteDeploymentExample
 * @dev Complete example showing how to deploy and configure the entire RWA token system
 * using clone factories for gas efficiency
 */
contract CompleteDeploymentExample is Script {
    // Factories
    TokenCloneFactory public tokenFactory;
    IdentityCloneFactory public identityFactory;
    ClaimTopicsRegistryCloneFactory public claimTopicsFactory;
    
    // Shared registries
    IdentityRegistry public identityRegistry;
    TrustedIssuersRegistry public trustedIssuersRegistry;
    
    // Actors
    address public admin;
    address public issuer;
    address public investor1;
    address public investor2;
    
    function run() external {
        // Setup addresses
        admin = vm.envOr("ADMIN_ADDRESS", address(0x1));
        issuer = vm.envOr("ISSUER_ADDRESS", address(0x2));
        investor1 = vm.envOr("INVESTOR1_ADDRESS", address(0x3));
        investor2 = vm.envOr("INVESTOR2_ADDRESS", address(0x4));
        
        vm.startBroadcast(admin);
        
        console.log("=== STEP 1: Deploy Factories ===");
        deployFactories();
        
        console.log("\n=== STEP 2: Deploy Shared Registries ===");
        deploySharedRegistries();
        
        console.log("\n=== STEP 3: Create Token A (Real Estate - Strict Requirements) ===");
        address tokenA = createRealEstateToken();
        
        console.log("\n=== STEP 4: Create Token B (Utility - Light Requirements) ===");
        address tokenB = createUtilityToken();
        
        console.log("\n=== STEP 5: Create Identities for Investors ===");
        createInvestorIdentities();
        
        vm.stopBroadcast();
        
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("Token Factory:", address(tokenFactory));
        console.log("Identity Factory:", address(identityFactory));
        console.log("ClaimTopics Factory:", address(claimTopicsFactory));
        console.log("Identity Registry:", address(identityRegistry));
        console.log("Trusted Issuers Registry:", address(trustedIssuersRegistry));
        console.log("Token A (Real Estate):", tokenA);
        console.log("Token B (Utility):", tokenB);
    }
    
    function deployFactories() internal {
        tokenFactory = new TokenCloneFactory(admin);
        console.log("Token Factory deployed at:", address(tokenFactory));
        
        identityFactory = new IdentityCloneFactory(admin);
        console.log("Identity Factory deployed at:", address(identityFactory));
        
        claimTopicsFactory = new ClaimTopicsRegistryCloneFactory(admin);
        console.log("ClaimTopics Factory deployed at:", address(claimTopicsFactory));
    }
    
    function deploySharedRegistries() internal {
        // Identity Registry - shared across all tokens
        identityRegistry = new IdentityRegistry(admin);
        console.log("Identity Registry deployed at:", address(identityRegistry));
        
        // Trusted Issuers Registry - shared across all tokens
        trustedIssuersRegistry = new TrustedIssuersRegistry(admin);
        console.log("Trusted Issuers Registry deployed at:", address(trustedIssuersRegistry));
        
        // Configure trusted issuer
        uint256[] memory topics = new uint256[](4);
        topics[0] = 1; // KYC
        topics[1] = 2; // AML
        topics[2] = 3; // Accredited Investor
        topics[3] = 4; // Tax Compliance
        
        trustedIssuersRegistry.addTrustedIssuer(issuer, topics);
        console.log("Trusted issuer configured:", issuer);
    }
    
    function createRealEstateToken() internal returns (address) {
        // Create ClaimTopicsRegistry with strict requirements
        uint256[] memory strictTopics = new uint256[](4);
        strictTopics[0] = 1; // KYC
        strictTopics[1] = 2; // AML
        strictTopics[2] = 3; // Accredited Investor
        strictTopics[3] = 4; // Tax Compliance
        
        address claimTopicsRegistry = claimTopicsFactory.createRegistryWithTopics(
            admin,
            strictTopics
        );
        console.log("ClaimTopics Registry created at:", claimTopicsRegistry);
        
        // Create token with all registries configured
        address token = tokenFactory.createTokenWithRegistries(
            "Real Estate Token",
            "REST",
            0, // No decimals for NFT-style
            admin,
            address(identityRegistry),
            address(trustedIssuersRegistry),
            claimTopicsRegistry
        );
        console.log("Real Estate Token created at:", token);
        
        return token;
    }
    
    function createUtilityToken() internal returns (address) {
        // Create ClaimTopicsRegistry with light requirements
        uint256[] memory lightTopics = new uint256[](1);
        lightTopics[0] = 1; // Only KYC
        
        address claimTopicsRegistry = claimTopicsFactory.createRegistryWithTopics(
            admin,
            lightTopics
        );
        console.log("ClaimTopics Registry created at:", claimTopicsRegistry);
        
        // Create token
        address token = tokenFactory.createTokenWithRegistries(
            "Utility Token",
            "UTL",
            18,
            admin,
            address(identityRegistry),
            address(trustedIssuersRegistry),
            claimTopicsRegistry
        );
        console.log("Utility Token created at:", token);
        
        return token;
    }
    
    function createInvestorIdentities() internal {
        // Create identity for investor1 with full claims
        address identity1 = identityFactory.createIdentityWithClaim(
            investor1,
            1, // KYC topic
            1, // ECDSA scheme
            issuer,
            hex"", // signature
            hex"", // data
            "" // uri
        );
        
        // Add more claims to investor1
        IdentityCloneable identityContract1 = IdentityCloneable(identity1);
        identityContract1.transferOwnership(admin);
        identityContract1.addClaim(2, 1, issuer, hex"", hex"", ""); // AML
        identityContract1.addClaim(3, 1, issuer, hex"", hex"", ""); // Accredited
        identityContract1.addClaim(4, 1, issuer, hex"", hex"", ""); // Tax
        identityContract1.transferOwnership(investor1);
        
        // Register identity
        identityRegistry.registerIdentity(investor1, identity1);
        console.log("Investor1 identity created and registered:", identity1);
        
        // Create identity for investor2 with only KYC
        address identity2 = identityFactory.createIdentityWithClaim(
            investor2,
            1, // KYC only
            1,
            issuer,
            hex"",
            hex"",
            ""
        );
        
        identityRegistry.registerIdentity(investor2, identity2);
        console.log("Investor2 identity created and registered:", identity2);
        
        console.log("\nInvestor1 can trade: Real Estate Token (has all claims)");
        console.log("Investor2 can trade: Utility Token only (has only KYC)");
    }
    
    function estimateGasSavings() internal view {
        console.log("\n=== GAS SAVINGS ESTIMATE ===");
        console.log(tokenFactory.getGasSavingsInfo());
        console.log(identityFactory.getGasSavingsInfo());
        console.log(claimTopicsFactory.getGasSavingsInfo());
        console.log("\nTotal savings per complete token deployment:");
        console.log("~3.3M gas saved using clone factories!");
    }
}

