// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenCloneFactory} from "../src/TokenCloneFactory.sol";
import {IdentityCloneFactory} from "../src/IdentityCloneFactory.sol";
import {ClaimTopicsRegistryCloneFactory} from "../src/ClaimTopicsRegistryCloneFactory.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";
import {IdentityCloneable} from "../src/IdentityCloneable.sol";
import {ClaimTopicsRegistryCloneable} from "../src/ClaimTopicsRegistryCloneable.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";

/**
 * @title CompleteDeploymentExample
 * @dev Ejemplo completo de despliegue y configuracion del sistema RWA usando factories de clones.
 *
 * AF-08 (Fase 4): corregido. Desde RF-001 `addClaim` exige una firma EIP-712 valida del issuer
 * (`IdentityCloneable.addClaim`), por lo que las firmas vacias `hex""` ya no son validas y el
 * script revertia. Ahora el issuer es una clave de prueba derivada de `ISSUER_PRIVATE_KEY`
 * (por defecto la misma que usan los tests) y cada claim se firma en el propio script con
 * `vm.sign`, igual que `sc/test/helpers/SigUtils.sol`. El camino canonico de despliegue sigue
 * siendo `DeployFullStack.s.sol` + `deploy.sh`; este archivo es un ejemplo didactico ejecutable.
 */
contract CompleteDeploymentExample is Script {
    // Factories
    TokenCloneFactory public tokenFactory;
    IdentityCloneFactory public identityFactory;
    ClaimTopicsRegistryCloneFactory public claimTopicsFactory;

    // Shared registries
    IdentityRegistry public identityRegistry;
    TrustedIssuersRegistry public trustedIssuersRegistry;

    // Actors
    address public admin;
    address public issuer;
    address public investor1;
    address public investor2;

    /// @dev Clave privada de prueba del issuer (misma que los tests: `ISSUER_PK = 0xB0B`).
    uint256 public issuerPk;

    /// @dev Tipo EIP-712 firmado por el issuer (D-020 + D-050: incluye `nonce`).
    bytes32 private constant CLAIM_TYPEHASH = keccak256(
        "Claim(address walletOwner,uint256 topic,uint256 scheme,bytes32 dataHash,uint256 expiresAt,uint256 nonce)"
    );

    /// @dev `keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")`
    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    function run() external {
        // Setup addresses
        admin = vm.envOr("ADMIN_ADDRESS", address(0x1));
        investor1 = vm.envOr("INVESTOR1_ADDRESS", address(0x3));
        investor2 = vm.envOr("INVESTOR2_ADDRESS", address(0x4));

        // AF-08: issuer de prueba con clave conocida; el contrato firma localmente con `vm.sign`.
        issuerPk = vm.envOr("ISSUER_PRIVATE_KEY", uint256(0xB0B));
        issuer = vm.addr(issuerPk);

        vm.startBroadcast(admin);

        console.log("=== STEP 1: Deploy Factories ===");
        deployFactories();

        console.log("\n=== STEP 2: Deploy Shared Registries ===");
        deploySharedRegistries();

        console.log("\n=== STEP 3: Create Token A (Real Estate - Strict Requirements) ===");
        address tokenA = createRealEstateToken();

        console.log("\n=== STEP 4: Create Token B (Utility - Light Requirements) ===");
        address tokenB = createUtilityToken();

        console.log("\n=== STEP 5: Create Identities for Investors ===");
        createInvestorIdentities();

        vm.stopBroadcast();

        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("Token Factory:", address(tokenFactory));
        console.log("Identity Factory:", address(identityFactory));
        console.log("ClaimTopics Factory:", address(claimTopicsFactory));
        console.log("Identity Registry:", address(identityRegistry));
        console.log("Trusted Issuers Registry:", address(trustedIssuersRegistry));
        console.log("Token A (Real Estate):", tokenA);
        console.log("Token B (Utility):", tokenB);
    }

    function deployFactories() internal {
        tokenFactory = new TokenCloneFactory(admin);
        console.log("Token Factory deployed at:", address(tokenFactory));

        identityFactory = new IdentityCloneFactory(admin);
        console.log("Identity Factory deployed at:", address(identityFactory));

        claimTopicsFactory = new ClaimTopicsRegistryCloneFactory(admin);
        console.log("ClaimTopics Factory deployed at:", address(claimTopicsFactory));
    }

    function deploySharedRegistries() internal {
        // Identity Registry - shared across all tokens
        identityRegistry = new IdentityRegistry(admin);
        console.log("Identity Registry deployed at:", address(identityRegistry));

        // Trusted Issuers Registry - shared across all tokens
        trustedIssuersRegistry = new TrustedIssuersRegistry(admin);
        console.log("Trusted Issuers Registry deployed at:", address(trustedIssuersRegistry));

        // Configure trusted issuer
        uint256[] memory topics = new uint256[](4);
        topics[0] = 1; // KYC
        topics[1] = 2; // AML
        topics[2] = 3; // Accredited Investor
        topics[3] = 4; // Tax Compliance

        trustedIssuersRegistry.addTrustedIssuer(issuer, topics);
        console.log("Trusted issuer configured:", issuer);
    }

    function createRealEstateToken() internal returns (address) {
        // Create ClaimTopicsRegistry with strict requirements
        uint256[] memory strictTopics = new uint256[](4);
        strictTopics[0] = 1; // KYC
        strictTopics[1] = 2; // AML
        strictTopics[2] = 3; // Accredited Investor
        strictTopics[3] = 4; // Tax Compliance

        address claimTopicsRegistry = claimTopicsFactory.createRegistryWithTopics(admin, strictTopics);
        console.log("ClaimTopics Registry created at:", claimTopicsRegistry);

        // Create token with all registries configured
        address token = tokenFactory.createTokenWithRegistries(
            "Real Estate Token",
            "REST",
            0, // No decimals for NFT-style
            admin,
            address(identityRegistry),
            address(trustedIssuersRegistry),
            claimTopicsRegistry
        );
        console.log("Real Estate Token created at:", token);

        return token;
    }

    function createUtilityToken() internal returns (address) {
        // Create ClaimTopicsRegistry with light requirements
        uint256[] memory lightTopics = new uint256[](1);
        lightTopics[0] = 1; // Only KYC

        address claimTopicsRegistry = claimTopicsFactory.createRegistryWithTopics(admin, lightTopics);
        console.log("ClaimTopics Registry created at:", claimTopicsRegistry);

        // Create token
        address token = tokenFactory.createTokenWithRegistries(
            "Utility Token",
            "UTL",
            18,
            admin,
            address(identityRegistry),
            address(trustedIssuersRegistry),
            claimTopicsRegistry
        );
        console.log("Utility Token created at:", token);

        return token;
    }

    function createInvestorIdentities() internal {
        // AF-08: firmas EIP-712 reales (RF-001). El digest incluye el `owner()` de la identidad
        // (el `admin` que la crea), el `nonce` vigente de `(topic, issuer)` y el
        // `verifyingContract` (la direccion del clon), exactamente como `SigUtils` en los tests.
        uint256 expiresAt = block.timestamp + 365 days;

        // Create identity for investor1 with full claims
        address identity1 = identityFactory.createIdentity(admin);
        IdentityCloneable identityContract1 = IdentityCloneable(identity1);

        _addSignedClaim(identityContract1, 1, abi.encode("KYC", identity1), expiresAt); // KYC
        _addSignedClaim(identityContract1, 2, abi.encode("AML", identity1), expiresAt); // AML
        _addSignedClaim(identityContract1, 3, abi.encode("ACCREDITED", identity1), expiresAt); // Accredited
        _addSignedClaim(identityContract1, 4, abi.encode("TAX", identity1), expiresAt); // Tax

        identityContract1.transferOwnership(investor1);

        // Register identity
        identityRegistry.registerIdentity(investor1, identity1);
        console.log("Investor1 identity created and registered:", identity1);

        // Create identity for investor2 with only KYC
        address identity2 = identityFactory.createIdentity(admin);
        IdentityCloneable identityContract2 = IdentityCloneable(identity2);
        _addSignedClaim(identityContract2, 1, abi.encode("KYC", identity2), expiresAt); // KYC only
        identityContract2.transferOwnership(investor2);

        identityRegistry.registerIdentity(investor2, identity2);
        console.log("Investor2 identity created and registered:", identity2);

        console.log("\nInvestor1 can trade: Real Estate Token (has all claims)");
        console.log("Investor2 can trade: Utility Token only (has only KYC)");
    }

    /// @dev Firma un claim EIP-712 con la clave de prueba del issuer y lo registra en la identidad.
    /// El `owner()` firmado es el owner actual del clon (admin) porque es quien llama a `addClaim`.
    function _addSignedClaim(IdentityCloneable identity, uint256 topic, bytes memory data, uint256 expiresAt) internal {
        uint256 nonce = identity.claimNonce(topic, issuer);
        bytes32 digest = _claimDigest(address(identity), identity.owner(), topic, data, expiresAt, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(issuerPk, digest);
        identity.addClaim(topic, 1, issuer, abi.encodePacked(r, s, v), data, "", expiresAt);
    }

    /// @dev Reproduce el digest EIP-712 de `IdentityCloneable` (D-020/D-026/D-050) sin depender de
    /// `sc/test/**`, para que el script de despliegue compile y se simule de forma autonoma.
    function _claimDigest(
        address verifyingContract,
        address walletOwner,
        uint256 topic,
        bytes memory data,
        uint256 expiresAt,
        uint256 nonce
    ) internal view returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes("RWA-Identity")),
                keccak256(bytes("1")),
                block.chainid,
                verifyingContract
            )
        );
        bytes32 structHash =
            keccak256(abi.encode(CLAIM_TYPEHASH, walletOwner, topic, uint256(1), keccak256(data), expiresAt, nonce));
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function estimateGasSavings() internal view {
        console.log("\n=== GAS SAVINGS ESTIMATE ===");
        console.log(tokenFactory.getGasSavingsInfo());
        console.log(identityFactory.getGasSavingsInfo());
        console.log(claimTopicsFactory.getGasSavingsInfo());
        console.log("\nTotal savings per complete token deployment:");
        console.log("~3.3M gas saved using clone factories!");
    }
}

