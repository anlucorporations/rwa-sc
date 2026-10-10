// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenCloneFactory} from "../src/TokenCloneFactory.sol";
import {IdentityCloneFactory} from "../src/IdentityCloneFactory.sol";
import {ClaimTopicsRegistryCloneFactory} from "../src/ClaimTopicsRegistryCloneFactory.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";
import {ComplianceAggregator} from "../src/compliance/ComplianceAggregator.sol";
import {MaxBalanceCompliance} from "../src/compliance/MaxBalanceCompliance.sol";

/**
 * @title DeployFullStack
 * @dev Script canonico end-to-end del Ciclo 9 (RF-010). Despliega la pila completa y deja
 *      un artefacto JSON verificable:
 *
 *        1. IdentityRegistry            (registro de identidades)
 *        2. TrustedIssuersRegistry      (issuers de confianza + topics)
 *        3. TokenCloneFactory           (factory EIP-1167 de tokens)
 *        4. IdentityCloneFactory        (factory EIP-1167 de identidades)
 *        5. ClaimTopicsRegistryCloneFactory (factory EIP-1167 de claim topics)
 *        6. ComplianceAggregator        (agregador de modulos de compliance)
 *        7. ClaimTopicsRegistry         (clon de ejemplo, via factory)
 *        8. Token                       (token de ejemplo, via `createTokenWithRegistries`)
 *        9. MaxBalanceCompliance        (modulo de compliance dado de alta **por la ruta del token**:
 *                                        `token.addComplianceModule(aggregator)` +
 *                                        `token.addModuleThroughAggregator(aggregator, module)`).
 *                                        **Obligatorio (AF-05):** sin modulos el token es fail-closed
 *                                        y no permite transferencias.
 *       10. Identity                    (clon de identidad de ejemplo, registrado en el IdentityRegistry)
 *
 *      La clave privada la aporta Foundry (keystore efimero gestionado por `deploy.sh`); este script
 *      nunca la lee ni la escribe. El artefacto se escribe en la ruta indicada por la variable de
 *      entorno `DEPLOYMENT_JSON` (por defecto `deployments/<chainId>-<block>.json` bajo la raiz del
 *      proyecto Foundry). `deploy.sh` completa despues el campo `abis`.
 *
 * Uso (normalmente a traves de `deploy.sh`):
 *   forge script script/DeployFullStack.s.sol:DeployFullStack \
 *     --rpc-url "$RPC_URL" --broadcast --keystore <path> --password-file <path>
 */
contract DeployFullStack is Script {
    struct Deployment {
        address identityRegistry;
        address trustedIssuersRegistry;
        address tokenFactory;
        address identityFactory;
        address claimTopicsFactory;
        address aggregator;
        address claimTopicsRegistry;
        address token;
        address complianceModule;
        address identity;
    }

    function run() external {
        address deployer = msg.sender;
        uint256 maxBalance = vm.envOr("MAX_BALANCE", uint256(1_000_000 ether));
        address demoIssuer = vm.envOr("ISSUER_ADDRESS", deployer);

        // AF-07: el despliegue canonico deja el token OPERABLE (no solo desplegado). Los topes de
        // `burn`/`forcedTransfer` y el destino autorizado de recuperacion se configuran aqui; el
        // `deploy.sh` los verifica con `cast call` (smoke test) antes de declarar "verde".
        uint256 maxBurnPerTx = vm.envOr("MAX_BURN_PER_TX", maxBalance);
        uint256 maxForcedPerTx = vm.envOr("MAX_FORCED_PER_TX", maxBalance);

        uint256[] memory topics = new uint256[](1);
        topics[0] = 1; // KYC

        console.log("=== RF-010/Ciclo 9: despliegue canonico de la pila RWA ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Max balance del modulo:", maxBalance);

        Deployment memory d;

        vm.startBroadcast();

        // 1-2. Registries compartidos
        d.identityRegistry = address(new IdentityRegistry(deployer));
        d.trustedIssuersRegistry = address(new TrustedIssuersRegistry(deployer));

        // 3-5. Factories de clones
        d.tokenFactory = address(new TokenCloneFactory(deployer));
        d.identityFactory = address(new IdentityCloneFactory(deployer));
        d.claimTopicsFactory = address(new ClaimTopicsRegistryCloneFactory(deployer));

        // 6. Aggregator de compliance
        d.aggregator = address(new ComplianceAggregator(deployer));

        // Configuracion del issuer de confianza (topics exigidos por el token de ejemplo)
        TrustedIssuersRegistry(d.trustedIssuersRegistry).addTrustedIssuer(demoIssuer, topics);

        // 7. ClaimTopicsRegistry del token, creado por la factory
        d.claimTopicsRegistry =
            ClaimTopicsRegistryCloneFactory(d.claimTopicsFactory).createRegistryWithTopics(deployer, topics);

        // 8. Token de ejemplo, creado por la factory con sus registries ya configurados
        d.token = TokenCloneFactory(d.tokenFactory)
            .createTokenWithRegistries(
                "RWA Demo Token",
                "RWAD",
                18,
                deployer,
                d.identityRegistry,
                d.trustedIssuersRegistry,
                d.claimTopicsRegistry
            );

        // 9. Modulo de compliance + alta por la ruta del token (token -> aggregator -> modulo).
        //    AF-05: este paso es OBLIGATORIO. El token es fail-closed sin modulos (`canTransfer`
        //    devuelve `false` con `complianceModules.length == 0`) y quedaria inoperable para
        //    transferencias. `deploy.sh` verifica on-chain que `complianceModules(0) == aggregator`.
        d.complianceModule = address(new MaxBalanceCompliance(deployer, maxBalance));
        MaxBalanceCompliance(d.complianceModule).setTokenContract(d.token);

        TokenCloneable tokenContract = TokenCloneable(d.token);
        tokenContract.addComplianceModule(d.aggregator);
        tokenContract.addModuleThroughAggregator(d.aggregator, d.complianceModule);

        // AF-07: configuracion obligatoria para que el token sea operable tras el despliegue.
        // (La identidad de ejemplo no tiene claims: `isVerified` es fail-closed, por lo que la
        // emision real requiere registrar una identidad con claim; el smoke test de `deploy.sh`
        // comprueba al menos topes, whitelist y registro del modulo.)
        tokenContract.setMaxBurnPerTx(maxBurnPerTx);
        tokenContract.setMaxForcedPerTx(maxForcedPerTx);
        tokenContract.setAuthorizedDestination(deployer, true);

        // 10. Identidad de ejemplo, creada por la factory y registrada en el IdentityRegistry
        d.identity = IdentityCloneFactory(d.identityFactory).createIdentity(deployer);
        IdentityRegistry(d.identityRegistry).registerIdentity(deployer, d.identity);

        vm.stopBroadcast();

        _persistArtifact(d, deployer, maxBalance, maxBurnPerTx, maxForcedPerTx);

        console.log("=== Despliegue completo ===");
        console.log("IdentityRegistry:", d.identityRegistry);
        console.log("TrustedIssuersRegistry:", d.trustedIssuersRegistry);
        console.log("TokenCloneFactory:", d.tokenFactory);
        console.log("IdentityCloneFactory:", d.identityFactory);
        console.log("ClaimTopicsRegistryCloneFactory:", d.claimTopicsFactory);
        console.log("ComplianceAggregator:", d.aggregator);
        console.log("ClaimTopicsRegistry:", d.claimTopicsRegistry);
        console.log("Token:", d.token);
        console.log("Compliance module (MaxBalance):", d.complianceModule);
        console.log("Identity:", d.identity);
        console.log("maxBurnPerTx:", maxBurnPerTx);
        console.log("maxForcedPerTx:", maxForcedPerTx);
        console.log("Destino autorizado (forcedTransfer):", deployer);
    }

    /// @dev Escribe el artefacto JSON trazable (sin secretos) en `DEPLOYMENT_JSON` o, por defecto,
    /// en `deployments/<chainId>-<block>.json`. El directorio debe existir (lo crea `deploy.sh`).
    function _persistArtifact(
        Deployment memory d,
        address deployer,
        uint256 maxBalance,
        uint256 maxBurnPerTx,
        uint256 maxForcedPerTx
    ) internal {
        TokenCloneable tokenContract = TokenCloneable(d.token);

        string memory contracts = "contracts";
        vm.serializeAddress(contracts, "IdentityRegistry", d.identityRegistry);
        vm.serializeAddress(contracts, "TrustedIssuersRegistry", d.trustedIssuersRegistry);
        vm.serializeAddress(contracts, "TokenCloneFactory", d.tokenFactory);
        vm.serializeAddress(contracts, "IdentityCloneFactory", d.identityFactory);
        vm.serializeAddress(contracts, "ClaimTopicsRegistryCloneFactory", d.claimTopicsFactory);
        vm.serializeAddress(contracts, "ComplianceAggregator", d.aggregator);
        vm.serializeAddress(contracts, "ClaimTopicsRegistry", d.claimTopicsRegistry);
        vm.serializeAddress(contracts, "Token", d.token);
        string memory contractsJson = vm.serializeAddress(contracts, "Identity", d.identity);

        string memory compliance = "compliance";
        vm.serializeAddress(compliance, "MaxBalanceCompliance", d.complianceModule);
        string memory complianceJson = vm.serializeUint(compliance, "maxBalance", maxBalance);

        string memory token = "token";
        vm.serializeAddress(token, "address", d.token);
        vm.serializeString(token, "name", tokenContract.name());
        vm.serializeString(token, "symbol", tokenContract.symbol());
        vm.serializeUint(token, "decimals", tokenContract.decimals());
        vm.serializeAddress(token, "identityRegistry", address(tokenContract.identityRegistry()));
        vm.serializeAddress(token, "trustedIssuersRegistry", address(tokenContract.trustedIssuersRegistry()));
        vm.serializeAddress(token, "claimTopicsRegistry", address(tokenContract.claimTopicsRegistry()));
        vm.serializeAddress(token, "complianceAggregator", d.aggregator);
        vm.serializeUint(token, "complianceModuleCount", ComplianceAggregator(d.aggregator).getModuleCount(d.token));
        // AF-07: los topes se serializan como string para que `jq` los devuelva exactos
        // (independientemente de la version/precision numerica de jq) y `deploy.sh` los compare.
        vm.serializeString(token, "maxBurnPerTx", vm.toString(maxBurnPerTx));
        vm.serializeString(token, "maxForcedPerTx", vm.toString(maxForcedPerTx));
        vm.serializeAddress(token, "authorizedDestination", deployer);
        string memory tokenJson = vm.serializeAddress(token, "complianceModule", d.complianceModule);

        string memory root = "deployment";
        vm.serializeUint(root, "chainId", block.chainid);
        vm.serializeUint(root, "block", block.number);
        vm.serializeUint(root, "timestamp", block.timestamp);
        vm.serializeAddress(root, "deployer", deployer);
        vm.serializeString(root, "contracts", contractsJson);
        vm.serializeString(root, "compliance", complianceJson);
        vm.serializeString(root, "token", tokenJson);

        string memory defaultPath =
            string.concat("deployments/", vm.toString(block.chainid), "-", vm.toString(block.number), ".json");
        string memory outPath = vm.envOr("DEPLOYMENT_JSON", defaultPath);
        string memory json = vm.serializeString(root, "paths", outPath);
        vm.writeJson(json, outPath);
        console.log("Artefacto de despliegue escrito en:", outPath);
    }
}
