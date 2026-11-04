// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {BarloToken} from "../../src/v3/BarloToken.sol";

/// @title DeployBarloToken
/// @notice Despliegue de C0 del token BRLT (ERC-20, 8 decimales) en la red canónica.
/// @dev La clave se lee SOLO de una variable de entorno (`ADMIN_PRIVATE_KEY` o la indicada por
///      `DEPLOYER_KEY_VAR`), nunca de argv ni de un archivo de claves (RF-010). El artefacto con
///      las direcciones se escribe en `deployments/` (fs_permissions del foundry.toml).
///
/// Uso:
///   source /home/dsh/workspace/gcp-env.sh
///   export PATH="$HOME/.foundry/bin:$PATH"
///   forge script script/v3/DeployBarloToken.s.sol --rpc-url "$RPC_URL" --broadcast
///
/// Variables opcionales:
///   BRLT_CAP                  cap en unidades mínimas (defecto 100.000.000 * 1e8)
///   BRLT_MAX_MINT_PER_TX      límite por tx en unidades mínimas (defecto 10.000 * 1e8)
///   BRLT_ADMIN                dirección admin/PAUSER del token (defecto: la del deployer)
///   DEPLOYER_KEY_VAR          nombre de la variable de entorno con la clave (defecto ADMIN_PRIVATE_KEY)
contract DeployBarloToken is Script {
    uint256 internal constant DEFAULT_CAP = 100_000_000 * 10 ** 8;
    uint256 internal constant DEFAULT_MAX_MINT = 10_000 * 10 ** 8;

    function run() external returns (BarloToken token) {
        string memory keyVar = vm.envOr("DEPLOYER_KEY_VAR", string("ADMIN_PRIVATE_KEY"));
        uint256 deployerKey = vm.envUint(keyVar);

        uint256 cap = vm.envOr("BRLT_CAP", DEFAULT_CAP);
        uint256 maxMint = vm.envOr("BRLT_MAX_MINT_PER_TX", DEFAULT_MAX_MINT);
        address admin = vm.envOr("BRLT_ADMIN", vm.addr(deployerKey));

        vm.startBroadcast(deployerKey);
        token = new BarloToken(admin, cap, maxMint);
        vm.stopBroadcast();

        string memory artifact = string.concat(
            "deployments/",
            vm.toString(block.chainid),
            "-",
            vm.toString(block.timestamp),
            "-barlo.json"
        );
        vm.writeJson(
            string.concat(
                '{"chainId":', vm.toString(block.chainid),
                ',"contract":"BarloToken","symbol":"BRLT","decimals":8',
                ',"address":"', vm.toString(address(token)), '"',
                ',"admin":"', vm.toString(admin), '"',
                ',"cap":"', vm.toString(cap), '"',
                ',"maxMintPerTx":"', vm.toString(maxMint), '"',
                ',"block":', vm.toString(block.number),
                '}'
            ),
            artifact
        );
    }
}
