// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AssetFactory} from "../../src/v3/AssetFactory.sol";

/// @notice Despliega el AssetFactory v3 apuntando al IdentityRegistry canónico.
/// @dev Variables: ADMIN_PRIVATE_KEY, IDENTITY_REGISTRY, GUARANTEE_TOPIC (11), GUARANTOR_TOPIC (12).
contract DeployAssets is Script {
    function run() external returns (AssetFactory factory) {
        uint256 pk = vm.envUint("ADMIN_PRIVATE_KEY");
        address registry = vm.envAddress("IDENTITY_REGISTRY");
        uint256 guaranteeTopic = vm.envOr("GUARANTEE_TOPIC", uint256(11));
        uint256 guarantorTopic = vm.envOr("GUARANTOR_TOPIC", uint256(12));
        address admin = vm.addr(pk);

        vm.startBroadcast(pk);
        factory = new AssetFactory(admin, registry, guaranteeTopic, guarantorTopic);
        vm.stopBroadcast();

        console.log("AssetFactory:", address(factory));
        console.log("admin:", admin);
        console.log("identityRegistry:", registry);

        string memory json = string.concat(
            '{"chainId":', vm.toString(block.chainid),
            ',"block":', vm.toString(block.number),
            ',"contracts":{"AssetFactory":"', vm.toString(address(factory)),
            '","IdentityRegistry":"', vm.toString(registry),
            '"},"topics":{"guarantee":', vm.toString(guaranteeTopic),
            ',"guarantor":', vm.toString(guarantorTopic),
            '},"admin":"', vm.toString(admin), '"}'
        );
        string memory path = string.concat(
            "deployments/", vm.toString(block.chainid), "-", vm.toString(block.timestamp), "-assets.json"
        );
        vm.writeFile(path, json);
        console.log("artifact:", path);
    }
}
