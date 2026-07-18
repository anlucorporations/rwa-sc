// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ComplianceAggregator} from "../src/compliance/ComplianceAggregator.sol";

/**
 * @title DeployComplianceAggregator
 * @dev Script to deploy the ComplianceAggregator contract
 *
 * Usage:
 * forge script script/DeployComplianceAggregator.s.sol:DeployComplianceAggregator \
 *   --rpc-url <RPC_URL> \
 *   --broadcast
 */
contract DeployComplianceAggregator is Script {
    function run() external returns (ComplianceAggregator aggregator) {
        address deployer = msg.sender;
        console.log("Deploying ComplianceAggregator with deployer:", deployer);

        vm.startBroadcast();

        // Deploy the aggregator
        aggregator = new ComplianceAggregator(deployer);

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("ComplianceAggregator deployed at:", address(aggregator));
        console.log("Owner:", aggregator.owner());
        
        console.log("\nNext Steps:");
        console.log("1. Configure tokens:");
        console.log("   aggregator.configureToken(tokenAddress, maxBalance, maxHolders, lockPeriod)");
        console.log("\n2. Add aggregator to tokens:");
        console.log("   token.addComplianceModule(address(aggregator))");
        
        console.log("\nBenefits:");
        console.log("- Single contract for all tokens");
        console.log("- ~67% gas savings vs separate modules");
        console.log("- Centralized compliance management");

        return aggregator;
    }
}

