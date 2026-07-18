// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ClaimTopicsRegistryCloneFactory} from "../src/ClaimTopicsRegistryCloneFactory.sol";

/**
 * @title DeployClaimTopicsRegistryCloneFactory
 * @dev Script to deploy the ClaimTopicsRegistryCloneFactory
 *
 * Usage:
 * forge script script/DeployClaimTopicsRegistryCloneFactory.s.sol:DeployClaimTopicsRegistryCloneFactory \
 *   --rpc-url <RPC_URL> \
 *   --broadcast \
 *   --private-key <PRIVATE_KEY>
 */
contract DeployClaimTopicsRegistryCloneFactory is Script {
    function run() external returns (ClaimTopicsRegistryCloneFactory factory) {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        
        console.log("Deploying ClaimTopicsRegistryCloneFactory...");
        console.log("Deployer:", deployer);
        
        vm.startBroadcast();
        
        factory = new ClaimTopicsRegistryCloneFactory(deployer);
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Complete ===");
        console.log("ClaimTopicsRegistryCloneFactory deployed at:", address(factory));
        console.log("Factory owner:", factory.owner());
        
        console.log("\nNext Steps:");
        console.log("Create registries by calling:");
        console.log("  factory.createRegistryWithTopics(owner, topics)");
        console.log("\nOr for a specific token:");
        console.log("  factory.createRegistryForTokenWithTopics(owner, tokenAddress, topics)");
        
        return factory;
    }
}

