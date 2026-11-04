// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";

/// @notice Fondea wallets dedicadas de rol desde la cuenta de desarrollo de Anvil (C0).
/// @dev Solo para el entorno de demo (Anvil GCP). La clave del fondeador se lee de
///      `DEPLOYER_PRIVATE_KEY` (env) y las direcciones destino de `BRLT_ADMIN_ADDRESS`,
///      `BRLT_MINTER_ADDRESS`, `BRLT_PAUSER_ADDRESS`. Nunca recibe claves por argv.
contract FundDevRoles is Script {
    uint256 internal constant FUND = 1 ether;

    function run() external {
        uint256 funderKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address[3] memory targets = [
            vm.envAddress("BRLT_ADMIN_ADDRESS"),
            vm.envAddress("BRLT_MINTER_ADDRESS"),
            vm.envAddress("BRLT_PAUSER_ADDRESS")
        ];

        vm.startBroadcast(funderKey);
        for (uint256 i = 0; i < targets.length; i++) {
            if (targets[i].balance < 0.5 ether) {
                (bool ok,) = targets[i].call{value: FUND}("");
                require(ok, "fund transfer failed");
            }
        }
        vm.stopBroadcast();
    }
}
