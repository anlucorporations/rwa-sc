// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {GovernanceMultisig} from "../src/GovernanceMultisig.sol";

/**
 * @title DeployGovernance
 * @dev H-06 (R-7 / D-021): despliega la gobernanza M-de-N con timelock.
 *
 * Variables de entorno (opcionales):
 *   GOVERNANCE_OWNER_1 / _2 / _3  — owners (por defecto: deployer + dos direcciones derivadas)
 *   GOVERNANCE_THRESHOLD          — aprobaciones necesarias (por defecto 2)
 *   GOVERNANCE_DELAY              — retardo en segundos (por defecto 1 dia)
 *
 * Uso:
 *   forge script script/DeployGovernance.s.sol:DeployGovernance --rpc-url "$RPC_URL" --broadcast ...
 *
 * Adopcion (post-despliegue): conceder `DEFAULT_ADMIN_ROLE`/`AGENT_ROLE`/`COMPLIANCE_ROLE` de los
 * contratos a la direccion del multisig y renunciar a los roles de la EOA. Ver `RUNBOOK_MIGRACION.md`.
 */
contract DeployGovernance is Script {
    function run() external {
        address deployer = msg.sender;

        address o1 = vm.envOr("GOVERNANCE_OWNER_1", deployer);
        address o2 = vm.envOr("GOVERNANCE_OWNER_2", _derive("rwa.governance.owner2"));
        address o3 = vm.envOr("GOVERNANCE_OWNER_3", _derive("rwa.governance.owner3"));
        uint256 threshold = vm.envOr("GOVERNANCE_THRESHOLD", uint256(2));
        uint256 delay = vm.envOr("GOVERNANCE_DELAY", uint256(1 days));

        address[] memory owners = new address[](3);
        owners[0] = o1;
        owners[1] = o2;
        owners[2] = o3;

        console.log("=== H-06: despliegue de la gobernanza (multisig + timelock) ===");
        console.log("Deployer:", deployer);
        console.log("Owner 1:", o1);
        console.log("Owner 2:", o2);
        console.log("Owner 3:", o3);
        console.log("Threshold:", threshold);
        console.log("Delay (s):", delay);

        vm.startBroadcast();
        GovernanceMultisig multisig = new GovernanceMultisig(owners, threshold, delay);
        vm.stopBroadcast();

        console.log("GovernanceMultisig:", address(multisig));
        console.log("Siguiente paso: conceder los roles admin al multisig y renunciar a los de la EOA.");
    }

    /// @dev Direccion determinista y distinta para los owners por defecto (sin claves reales).
    function _derive(string memory label) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(label)))));
    }
}
