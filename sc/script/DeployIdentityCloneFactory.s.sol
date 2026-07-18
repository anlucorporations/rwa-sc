// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IdentityCloneFactory} from "../src/IdentityCloneFactory.sol";

/**
 * @title DeployIdentityCloneFactory
 * @dev Script to deploy the IdentityCloneFactory
 *
 * Usage:
 * forge script script/DeployIdentityCloneFactory.s.sol:DeployIdentityCloneFactory \
 *   --rpc-url <RPC_URL> \
 *   --broadcast
 */
contract DeployIdentityCloneFactory is Script {
    function run() external returns (IdentityCloneFactory factory) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying IdentityCloneFactory...");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the IdentityCloneFactory
        factory = new IdentityCloneFactory(deployer);

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("IdentityCloneFactory deployed at:", address(factory));
        console.log("Implementation contract:", factory.implementation());
        console.log("Factory owner:", factory.owner());
        
        console.log("\nNext Steps:");
        console.log("Create identities by calling:");
        console.log("  factory.createIdentity(ownerAddress)");
        console.log("\nOr with a claim:");
        console.log("  factory.createIdentityWithClaim(owner, topic, scheme, issuer, signature, data, uri)");

        return factory;
    }
}

