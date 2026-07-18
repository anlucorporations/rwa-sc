// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IdentityCloneFactory} from "../src/IdentityCloneFactory.sol";
import {IdentityCloneable} from "../src/IdentityCloneable.sol";

contract IdentityCloneFactoryTest is Test {
    IdentityCloneFactory public factory;
    address public owner;
    address public user1;
    address public user2;
    address public issuer;

    event IdentityCreated(address indexed identity, address indexed owner);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        issuer = makeAddr("issuer");

        factory = new IdentityCloneFactory(owner);
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
        vm.startPrank(user1);
        bytes32 claimId = contract1.addClaim(
            1, // KYC topic
            1, // ECDSA scheme
            issuer,
            hex"123456",
            abi.encode(user1, true),
            "https://kyc.example.com/user1"
        );
        vm.stopPrank();

        // Verify claim exists in identity1
        assertTrue(contract1.claimExists(1, issuer));

        // Verify claim does NOT exist in identity2
        assertFalse(contract2.claimExists(1, issuer));
    }

    function testCreateIdentityWithClaim() public {
        uint256 topic = 1;
        uint256 scheme = 1;
        bytes memory signature = hex"abcdef123456";
        bytes memory data = abi.encode(user1, true);
        string memory uri = "https://kyc.example.com";

        address identity = factory.createIdentityWithClaim(
            user1,
            topic,
            scheme,
            issuer,
            signature,
            data,
            uri
        );

        IdentityCloneable identityContract = IdentityCloneable(identity);

        // Verify ownership
        assertEq(identityContract.owner(), user1);

        // Verify claim exists
        assertTrue(identityContract.claimExists(topic, issuer));

        // Verify claim data
        (
            uint256 returnedTopic,
            uint256 returnedScheme,
            address returnedIssuer,
            bytes memory returnedSignature,
            bytes memory returnedData,
            string memory returnedUri
        ) = identityContract.getClaim(topic, issuer);

        assertEq(returnedTopic, topic);
        assertEq(returnedScheme, scheme);
        assertEq(returnedIssuer, issuer);
        assertEq(returnedSignature, signature);
        assertEq(returnedData, data);
        assertEq(returnedUri, uri);
    }

    function testGetIdentityAtRevertsOnInvalidIndex() public {
        factory.createIdentity(user1);

        vm.expectRevert("Index out of bounds");
        factory.getIdentityAt(1);
    }

    function testGasSavings() public {
        // Measure gas for creating a clone
        uint256 gasBefore = gasleft();
        factory.createIdentity(user1);
        uint256 cloneGas = gasBefore - gasleft();

        // Measure gas for deploying a full IdentityCloneable contract
        gasBefore = gasleft();
        new IdentityCloneable();
        uint256 fullDeployGas = gasBefore - gasleft();

        console.log("Clone deployment gas:", cloneGas);
        console.log("Full deployment gas:", fullDeployGas);
        console.log("Gas savings:", fullDeployGas - cloneGas);
        console.log("Savings percentage:", ((fullDeployGas - cloneGas) * 100) / fullDeployGas);

        // Clone should use significantly less gas (at least 80% savings)
        assertTrue(cloneGas < fullDeployGas / 5); // At least 80% savings
    }

    function testMultipleClaimsOnClonedIdentity() public {
        address identity = factory.createIdentity(user1);
        IdentityCloneable identityContract = IdentityCloneable(identity);

        vm.startPrank(user1);

        // Add KYC claim
        identityContract.addClaim(
            1, // KYC
            1,
            issuer,
            hex"aabb11",
            abi.encode(user1, "KYC approved"),
            "https://kyc.example.com"
        );

        // Add accreditation claim
        identityContract.addClaim(
            2, // Accreditation
            1,
            issuer,
            hex"ccdd22",
            abi.encode(user1, "Accredited investor"),
            "https://accreditation.example.com"
        );

        vm.stopPrank();

        // Verify both claims exist
        assertTrue(identityContract.claimExists(1, issuer));
        assertTrue(identityContract.claimExists(2, issuer));
    }

    function testClonedIdentityCanRemoveClaims() public {
        address identity = factory.createIdentity(user1);
        IdentityCloneable identityContract = IdentityCloneable(identity);

        vm.startPrank(user1);

        // Add claim
        identityContract.addClaim(1, 1, issuer, hex"aabbcc", abi.encode(user1), "https://example.com");
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
