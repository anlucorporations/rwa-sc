// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenCloneFactory} from "../src/TokenCloneFactory.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";

/**
 * @title DeployTokenCloneFactory
 * @dev Script to deploy the TokenCloneFactory
 *
 * Usage:
 * forge script script/DeployTokenCloneFactory.s.sol:DeployTokenCloneFactory --rpc-url <RPC_URL> --broadcast
 */
contract DeployTokenCloneFactory is Script {
    function run() external returns (TokenCloneFactory factory) {
        address deployer = msg.sender;
        console.log("Deploying TokenCloneFactory with deployer:", deployer);

        vm.startBroadcast();

        // Deploy the factory (it will automatically deploy the implementation)
        factory = new TokenCloneFactory(deployer);

        vm.stopBroadcast();

        console.log("TokenCloneFactory deployed at:", address(factory));
        console.log("Implementation deployed at:", factory.implementation());
        console.log("Factory owner:", factory.owner());
        console.log("\nGas savings info:");
        console.log(factory.getGasSavingsInfo());

        return factory;
    }
}

