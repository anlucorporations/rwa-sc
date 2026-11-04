// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {BarloToken} from "../../src/v3/BarloToken.sol";

/// @notice Concede MINTER_ROLE y PAUSER_ROLE del BRLT a las wallets dedicadas (C0).
/// @dev Las claves se leen de variables de entorno (nunca argv): `BRLT_ADMIN_PRIVATE_KEY`,
///      y las direcciones de `BRLT_MINTER_ADDRESS` / `BRLT_PAUSER_ADDRESS`.
///      El token se indica con `BRLT_ADDRESS`.
contract GrantBarloRoles is Script {
    function run() external {
        uint256 adminKey = vm.envUint("BRLT_ADMIN_PRIVATE_KEY");
        address tokenAddr = vm.envAddress("BRLT_ADDRESS");
        address minter = vm.envAddress("BRLT_MINTER_ADDRESS");
        address pauser = vm.envAddress("BRLT_PAUSER_ADDRESS");

        BarloToken token = BarloToken(tokenAddr);

        vm.startBroadcast(adminKey);
        if (!token.hasRole(token.MINTER_ROLE(), minter)) {
            token.grantRole(token.MINTER_ROLE(), minter);
        }
        if (!token.hasRole(token.PAUSER_ROLE(), pauser)) {
            token.grantRole(token.PAUSER_ROLE(), pauser);
        }
        vm.stopBroadcast();
    }
}
