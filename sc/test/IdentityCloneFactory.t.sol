// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IdentityCloneFactory} from "../src/IdentityCloneFactory.sol";
import {IdentityCloneable} from "../src/IdentityCloneable.sol";
import {IdentityBenchmark, IdentityWithClaimBenchmark} from "./benchmarks/IdentityBenchmark.sol";
import {BenchmarkDeployer} from "./benchmarks/BenchmarkDeployer.sol";
import {SigUtils} from "./helpers/SigUtils.sol";

contract IdentityCloneFactoryTest is Test {
    IdentityCloneFactory public factory;
    address public owner;
    address public user1;
    address public user2;
    address public issuer;

    uint256 internal constant ISSUER_PK = 0xB0B;
    uint256 internal constant EXPIRES_AT = 2_000_000_000;

    event IdentityCreated(address indexed identity, address indexed owner);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        issuer = vm.addr(ISSUER_PK);

        factory = new IdentityCloneFactory(owner);
    }

    /// H-07: una cuenta no autorizada no puede crear identidades.
    function test_H07_CreateIdentity_sin_autorizacion_revierte() public {
        address stranger = makeAddr("strangerH07");
        vm.prank(stranger);
        vm.expectRevert("Not authorized to create");
        factory.createIdentity(user1);
    }

    /// H-07: el owner autoriza a un tercero y este puede crear.
    function test_H07_SetAuthorizedCreator_autoriza() public {
        address relay = makeAddr("relayH07");
        factory.setAuthorizedCreator(relay, true);

        vm.prank(relay);
        address identity = factory.createIdentity(user2);
        assertNotEq(identity, address(0));
        assertEq(IdentityCloneable(identity).owner(), user2);
    }

    /// @dev Firma EIP-712 (RF-001) para una identidad concreta. AF-03: la firma cubre el `uri`.
    function _sign(
        address identity,
        address walletOwner,
        uint256 topic,
        bytes memory data,
        uint256 expiresAt,
        string memory uri
    ) internal view returns (bytes memory) {
        return SigUtils.signClaim(ISSUER_PK, identity, walletOwner, topic, 1, data, expiresAt, 0, uri);
    }

    function testDeployment() public view {
        assertEq(factory.owner(), owner);
        assertTrue(factory.implementation() != address(0));
        assertEq(factory.getTotalIdentities(), 0);
    }

    function testCreateIdentity() public {
        address identity = factory.createIdentity(user1);

        assertTrue(identity != address(0));
        assertEq(factory.getTotalIdentities(), 1);
        assertEq(factory.getIdentityAt(0), identity);

        IdentityCloneable identityContract = IdentityCloneable(identity);
        assertEq(identityContract.owner(), user1);
    }

    function testCreateMultipleIdentities() public {
        address identity1 = factory.createIdentity(user1);
        address identity2 = factory.createIdentity(user2);
        address identity3 = factory.createIdentity(user1); // user1 creates another identity

        assertEq(factory.getTotalIdentities(), 3);
        assertTrue(identity1 != identity2);
        assertTrue(identity1 != identity3);
        assertTrue(identity2 != identity3);

        // Check user1 has 2 identities
        address[] memory user1Identities = factory.getIdentitiesByOwner(user1);
        assertEq(user1Identities.length, 2);
        assertEq(user1Identities[0], identity1);
        assertEq(user1Identities[1], identity3);

        // Check user2 has 1 identity
        address[] memory user2Identities = factory.getIdentitiesByOwner(user2);
        assertEq(user2Identities.length, 1);
        assertEq(user2Identities[0], identity2);
    }

    function testCreateIdentityRevertsOnZeroAddress() public {
        vm.expectRevert("Invalid owner address");
        factory.createIdentity(address(0));
    }

    function testClonedIdentityIsIndependent() public {
        address identity1 = factory.createIdentity(user1);
        address identity2 = factory.createIdentity(user2);

        IdentityCloneable contract1 = IdentityCloneable(identity1);
        IdentityCloneable contract2 = IdentityCloneable(identity2);

        // Add claim to identity1 as user1
        bytes memory data = abi.encode(user1, true);
        bytes memory signature = _sign(identity1, user1, 1, data, EXPIRES_AT, "https://kyc.example.com/user1");
        vm.startPrank(user1);
        bytes32 claimId = contract1.addClaim(
            1, // KYC topic
            1, // ECDSA scheme
            issuer,
            signature,
            data,
            "https://kyc.example.com/user1",
            EXPIRES_AT
        );
        vm.stopPrank();

        // El claimId derivado en assembly es keccak256(abi.encode(issuer, topic))
        assertEq(claimId, keccak256(abi.encode(issuer, uint256(1))));

        // Verify claim exists in identity1
        assertTrue(contract1.claimExists(1, issuer));

        // Verify claim does NOT exist in identity2
        assertFalse(contract2.claimExists(1, issuer));
    }

    function testCreateIdentityWithClaim() public {
        bytes memory data = abi.encode(user1, true);
        string memory uri = "https://kyc.example.com";

        // `createIdentityWithClaim` inicializa el clon con la factory como owner
        // temporal (necesario para llamar a `addClaim`, onlyOwner), de modo que el
        // `walletOwner` firmado es la factory. La direccion del clon se predice por CREATE.
        address predicted = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)));
        bytes memory signature = _sign(predicted, address(factory), 1, data, EXPIRES_AT, uri);

        address identity = factory.createIdentityWithClaim(user1, 1, 1, issuer, signature, data, uri, EXPIRES_AT);
        assertEq(identity, predicted, "la direccion del clon debe ser predecible");
        assertEq(IdentityCloneable(identity).owner(), user1);

        _assertClaimStored(IdentityCloneable(identity), 1, 1, issuer, signature, data, uri, EXPIRES_AT);
    }

    /// @dev Comprueba los 8 campos de un claim almacenado (RF-001 + RF-013). Se lee `getClaim`
    /// en bloques para no agotar la pila con la tupla de 8 campos.
    function _assertClaimStored(
        IdentityCloneable identityContract,
        uint256 expectedTopic,
        uint256 expectedScheme,
        address expectedIssuer,
        bytes memory expectedSignature,
        bytes memory expectedData,
        string memory expectedUri,
        uint256 expectedExpiresAt
    ) internal view {
        assertTrue(identityContract.claimExists(expectedTopic, expectedIssuer));

        {
            (uint256 returnedTopic, uint256 returnedScheme, address returnedIssuer,,,,,) =
                identityContract.getClaim(expectedTopic, expectedIssuer);
            assertEq(returnedTopic, expectedTopic);
            assertEq(returnedScheme, expectedScheme);
            assertEq(returnedIssuer, expectedIssuer);
        }
        {
            (,,, bytes memory returnedSignature, bytes memory returnedData, string memory returnedUri,,) =
                identityContract.getClaim(expectedTopic, expectedIssuer);
            assertEq(returnedSignature, expectedSignature);
            assertEq(returnedData, expectedData);
            assertEq(returnedUri, expectedUri);
        }
        {
            (,,,,,, uint256 returnedExpiresAt, bool returnedRevoked) =
                identityContract.getClaim(expectedTopic, expectedIssuer);
            assertEq(returnedExpiresAt, expectedExpiresAt);
            assertFalse(returnedRevoked, "un claim recien creado no esta revocado");
        }
    }

    function testGetIdentityAtRevertsOnInvalidIndex() public {
        factory.createIdentity(user1);

        vm.expectRevert("Index out of bounds");
        factory.getIdentityAt(1);
    }

    function testGasSavings() public {
        // Comparación EQUIVALENTE (H-03 / B-7): "clon EIP-1167 + initialize"
        // contra "despliegue completo + inicialización equivalente" (IdentityBenchmark,
        // no-upgradeable y con el mismo almacenamiento/claim). Ver test/benchmarks/.

        // (1) Identidad simple (owner, sin claim)
        uint256 gasBefore = gasleft();
        factory.createIdentity(user1);
        uint256 cloneGas = gasBefore - gasleft();

        gasBefore = gasleft();
        address simpleBaseline = BenchmarkDeployer.deployIdentityBenchmark(user1);
        uint256 fullDeployGas = gasBefore - gasleft();

        assertEq(IdentityBenchmark(simpleBaseline).owner(), user1);

        console.log("Clone createIdentity gas:", cloneGas);
        console.log("Full deployment gas:", fullDeployGas);

        uint256 simpleSaved = fullDeployGas - cloneGas;
        console.log("Gas saved:", simpleSaved);
        console.log("Savings percentage:", (simpleSaved * 100) / fullDeployGas);

        assertTrue(cloneGas < fullDeployGas, "Clone must be cheaper than full deployment");
        assertGe(simpleSaved * 100, fullDeployGas * 45, "Clone should save at least 45% gas");
        assertGt(simpleSaved, 200_000, "Absolute saving should exceed 200k gas");

        // (2) Identidad con claim inicial (mismo trabajo que createIdentityWithClaim)
        bytes memory data = abi.encode(user1, true);
        string memory uri = "https://kyc.example.com";

        // Firma EIP-712 valida para el clon que va a crear la factory (RF-001).
        address predicted = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)));
        bytes memory signature = _sign(predicted, address(factory), 1, data, EXPIRES_AT, uri);

        gasBefore = gasleft();
        factory.createIdentityWithClaim(user1, 1, 1, issuer, signature, data, uri, EXPIRES_AT);
        uint256 cloneClaimGas = gasBefore - gasleft();

        gasBefore = gasleft();
        address claimBaseline =
            BenchmarkDeployer.deployIdentityWithClaimBenchmark(user1, 1, 1, issuer, signature, data, uri, EXPIRES_AT);
        uint256 fullClaimGas = gasBefore - gasleft();

        assertEq(IdentityWithClaimBenchmark(claimBaseline).owner(), user1);
        assertTrue(IdentityWithClaimBenchmark(claimBaseline).claimExists(1, issuer));

        console.log("Clone createIdentityWithClaim gas:", cloneClaimGas);
        console.log("Full deployment + claim gas:", fullClaimGas);

        uint256 claimSaved = fullClaimGas - cloneClaimGas;
        console.log("Gas saved with claim:", claimSaved);
        console.log("Savings percentage with claim:", (claimSaved * 100) / fullClaimGas);

        assertTrue(cloneClaimGas < fullClaimGas, "Clone with claim must be cheaper");
        assertGe(claimSaved * 100, fullClaimGas * 40, "Clone with claim should save at least 40% gas");
        assertGt(claimSaved, 200_000, "Absolute saving with claim should exceed 200k gas");
    }

    function testMultipleClaimsOnClonedIdentity() public {
        address identity = factory.createIdentity(user1);
        IdentityCloneable identityContract = IdentityCloneable(identity);

        bytes memory kycData = abi.encode(user1, "KYC approved");
        bytes memory accData = abi.encode(user1, "Accredited investor");
        bytes memory kycSig = _sign(identity, user1, 1, kycData, EXPIRES_AT, "https://kyc.example.com");
        bytes memory accSig = _sign(identity, user1, 2, accData, EXPIRES_AT, "https://accreditation.example.com");

        vm.startPrank(user1);

        // Add KYC claim
        identityContract.addClaim(1, 1, issuer, kycSig, kycData, "https://kyc.example.com", EXPIRES_AT);

        // Add accreditation claim
        identityContract.addClaim(2, 1, issuer, accSig, accData, "https://accreditation.example.com", EXPIRES_AT);

        vm.stopPrank();

        // Verify both claims exist
        assertTrue(identityContract.claimExists(1, issuer));
        assertTrue(identityContract.claimExists(2, issuer));
    }

    function testClonedIdentityCanRemoveClaims() public {
        address identity = factory.createIdentity(user1);
        IdentityCloneable identityContract = IdentityCloneable(identity);

        bytes memory data = abi.encode(user1);
        bytes memory signature = _sign(identity, user1, 1, data, EXPIRES_AT, "https://example.com");

        vm.startPrank(user1);

        // Add claim
        identityContract.addClaim(1, 1, issuer, signature, data, "https://example.com", EXPIRES_AT);
        assertTrue(identityContract.claimExists(1, issuer));

        // Remove claim
        identityContract.removeClaim(1, issuer);
        assertFalse(identityContract.claimExists(1, issuer));

        vm.stopPrank();
    }

    function testFuzzCreateIdentity(address randomUser) public {
        vm.assume(randomUser != address(0));

        address identity = factory.createIdentity(randomUser);
        IdentityCloneable identityContract = IdentityCloneable(identity);

        assertEq(identityContract.owner(), randomUser);
        assertTrue(identity != address(0));
    }

    function testGetGasSavingsInfo() public view {
        string memory info = factory.getGasSavingsInfo();
        assertTrue(bytes(info).length > 0);
    }
}
