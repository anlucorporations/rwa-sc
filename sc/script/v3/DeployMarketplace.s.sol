// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Marketplace} from "../../src/v3/Marketplace.sol";

/// @notice Despliega el Marketplace (escrow en BRLT) en la red canónica.
/// @dev Variables: ADMIN_PRIVATE_KEY, BRLT_ADDRESS.
contract DeployMarketplace is Script {
    function run() external returns (Marketplace market) {
        uint256 pk = vm.envUint("ADMIN_PRIVATE_KEY");
        address brlt = vm.envAddress("BRLT_ADDRESS");
        address admin = vm.addr(pk);

        vm.startBroadcast(pk);
        market = new Marketplace(admin, brlt);
        vm.stopBroadcast();

        console.log("Marketplace:", address(market));
        string memory json = string.concat(
            '{"chainId":', vm.toString(block.chainid),
            ',"block":', vm.toString(block.number),
            ',"contracts":{"Marketplace":"', vm.toString(address(market)),
            '","BRLT":"', vm.toString(brlt),
            '"},"admin":"', vm.toString(admin), '"}'
        );
        string memory path = string.concat(
            "deployments/", vm.toString(block.chainid), "-", vm.toString(block.timestamp), "-market.json"
        );
        vm.writeFile(path, json);
        console.log("artifact:", path);
    }
}
