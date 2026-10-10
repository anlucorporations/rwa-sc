// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenCloneFactory} from "../src/TokenCloneFactory.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";

/**
 * @title CreateTokenWithCloneFactory
 * @dev Script to create a new Token using the TokenCloneFactory
 *
 * Usage:
 * forge script script/CreateTokenWithCloneFactory.s.sol:CreateTokenWithCloneFactory \
 *   --rpc-url <RPC_URL> \
 *   --broadcast \
 *   --sig "run(address,string,string,uint8,address)" \
 *   <FACTORY_ADDRESS> <TOKEN_NAME> <TOKEN_SYMBOL> <DECIMALS> <ADMIN_ADDRESS>
 */
contract CreateTokenWithCloneFactory is Script {
    function run(
        address factoryAddress,
        string memory tokenName,
        string memory tokenSymbol,
        uint8 decimals,
        address admin
    ) external returns (address tokenAddress) {
        require(factoryAddress != address(0), "Invalid factory address");
        require(admin != address(0), "Invalid admin address");

        console.log("Creating token using factory at:", factoryAddress);
        console.log("Token name:", tokenName);
        console.log("Token symbol:", tokenSymbol);
        console.log("Decimals:", decimals);
        console.log("Admin:", admin);

        TokenCloneFactory factory = TokenCloneFactory(factoryAddress);

        vm.startBroadcast();

        tokenAddress = factory.createToken(tokenName, tokenSymbol, decimals, admin);

        vm.stopBroadcast();

        console.log("\nToken created at:", tokenAddress);
        console.log("Total tokens created:", factory.getTotalTokens());

        // Display token info
        TokenCloneable token = TokenCloneable(tokenAddress);
        console.log("\nToken information:");
        console.log("  Name:", token.name());
        console.log("  Symbol:", token.symbol());
        console.log("  Decimals:", token.decimals());
        console.log("  Admin has DEFAULT_ADMIN_ROLE:", token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        console.log("  Admin has AGENT_ROLE:", token.hasRole(token.AGENT_ROLE(), admin));
        console.log("  Admin has COMPLIANCE_ROLE:", token.hasRole(token.COMPLIANCE_ROLE(), admin));

        return tokenAddress;
    }

    // Simplified run function for local testing
    function run() external returns (address tokenAddress) {
        // Default values for local testing
        string memory tokenName = "Security Token";
        string memory tokenSymbol = "SEC";
        uint8 decimals = 18;
        address admin = msg.sender;

        console.log("Deploying factory and creating token...");

        vm.startBroadcast();

        // Deploy factory
        TokenCloneFactory factory = new TokenCloneFactory(msg.sender);
        console.log("Factory deployed at:", address(factory));

        // Create token
        tokenAddress = factory.createToken(tokenName, tokenSymbol, decimals, admin);

        vm.stopBroadcast();

        console.log("Token created at:", tokenAddress);

        return tokenAddress;
    }
}
