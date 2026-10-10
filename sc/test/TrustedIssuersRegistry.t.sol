// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TrustedIssuersRegistry} from "../src/TrustedIssuersRegistry.sol";

/// @dev Suite dedicada de `TrustedIssuersRegistry` (Ciclo 1b).
/// Cubre todas las funciones externas, control de acceso, caminos de revierte,
/// eventos, vistas, borrado con swap-and-pop y fuzz de listas de topics/issues.
contract TrustedIssuersRegistryTest is Test {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TrustedIssuerAdded(address indexed issuer, uint256[] claimTopics);
    event TrustedIssuerRemoved(address indexed issuer);
    event ClaimTopicsUpdated(address indexed issuer, uint256[] claimTopics);

    TrustedIssuersRegistry internal registry;

    address internal owner;
    address internal nonOwner;

    address internal issuer1;
    address internal issuer2;
    address internal issuer3;

    function setUp() public {
        owner = address(this);
        nonOwner = makeAddr("nonOwner");

        issuer1 = makeAddr("issuer1");
        issuer2 = makeAddr("issuer2");
        issuer3 = makeAddr("issuer3");

        registry = new TrustedIssuersRegistry(owner);
    }

    // ---------------------------------------------------------------------
    // Constructor / Ownable
    // ---------------------------------------------------------------------

    function test_Constructor_SetsInitialOwner() public {
        TrustedIssuersRegistry fresh = new TrustedIssuersRegistry(nonOwner);
        assertEq(fresh.owner(), nonOwner);
    }

    function test_Constructor_EmitsOwnershipTransferred() public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(0), nonOwner);
        new TrustedIssuersRegistry(nonOwner);
    }

    function test_Constructor_RevertWhen_OwnerIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new TrustedIssuersRegistry(address(0));
    }

    // ---------------------------------------------------------------------
    // addTrustedIssuer
    // ---------------------------------------------------------------------

    function test_AddTrustedIssuer() public {
        uint256[] memory topics = _twoTopics(1, 2);

        vm.expectEmit(true, false, false, true, address(registry));
        emit TrustedIssuerAdded(issuer1, topics);

        registry.addTrustedIssuer(issuer1, topics);

        assertTrue(registry.isTrustedIssuer(issuer1));
        assertEq(registry.getTrustedIssuersCount(), 1);
        assertEq(registry.getTrustedIssuers()[0], issuer1);
        _assertTopicsEq(registry.getIssuerClaimTopics(issuer1), topics);
        assertTrue(registry.hasClaimTopic(issuer1, 1));
        assertTrue(registry.hasClaimTopic(issuer1, 2));
    }

    function test_AddTrustedIssuer_MultipleKeepsInsertionOrder() public {
        registry.addTrustedIssuer(issuer1, _oneTopic(1));
        registry.addTrustedIssuer(issuer2, _oneTopic(2));
        registry.addTrustedIssuer(issuer3, _oneTopic(3));

        assertEq(registry.getTrustedIssuersCount(), 3);
        address[] memory list = registry.getTrustedIssuers();
        assertEq(list[0], issuer1);
        assertEq(list[1], issuer2);
        assertEq(list[2], issuer3);
        _assertNoHoles();
    }

    function test_AddTrustedIssuer_CanReAddAfterRemoval() public {
        registry.addTrustedIssuer(issuer1, _oneTopic(1));
        registry.removeTrustedIssuer(issuer1);
        assertEq(registry.getTrustedIssuersCount(), 0);

        registry.addTrustedIssuer(issuer1, _twoTopics(5, 6));

        assertTrue(registry.isTrustedIssuer(issuer1));
        assertEq(registry.getTrustedIssuersCount(), 1);
        assertEq(registry.getTrustedIssuers()[0], issuer1);
        assertTrue(registry.hasClaimTopic(issuer1, 5));
        assertTrue(registry.hasClaimTopic(issuer1, 6));
        _assertNoHoles();
    }

    function test_AddTrustedIssuer_RevertWhen_IssuerIsZero() public {
        vm.expectRevert("Invalid issuer address");
        registry.addTrustedIssuer(address(0), _oneTopic(1));
    }

    function test_AddTrustedIssuer_RevertWhen_AlreadyTrusted() public {
        registry.addTrustedIssuer(issuer1, _oneTopic(1));

        vm.expectRevert("Issuer already trusted");
        registry.addTrustedIssuer(issuer1, _oneTopic(2));
    }

    function test_AddTrustedIssuer_RevertWhen_NoClaimTopics() public {
        uint256[] memory empty = new uint256[](0);

        vm.expectRevert("Must specify at least one claim topic");
        registry.addTrustedIssuer(issuer1, empty);
    }

    function test_AddTrustedIssuer_RevertWhen_NotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.addTrustedIssuer(issuer1, _oneTopic(1));
    }

    // ---------------------------------------------------------------------
    // removeTrustedIssuer (swap-and-pop)
    // ---------------------------------------------------------------------

    function test_RemoveTrustedIssuer_FirstSwapsLast() public {
        _addThree();

        vm.expectEmit(true, false, false, false, address(registry));
        emit TrustedIssuerRemoved(issuer1);

        registry.removeTrustedIssuer(issuer1);

        assertFalse(registry.isTrustedIssuer(issuer1));
        assertEq(registry.getIssuerClaimTopics(issuer1).length, 0);
        assertFalse(registry.hasClaimTopic(issuer1, 1));
        assertEq(registry.getTrustedIssuersCount(), 2);
        address[] memory list = registry.getTrustedIssuers();
        assertEq(list[0], issuer3); // el último ocupa el hueco
        assertEq(list[1], issuer2);
        _assertNoHoles();
    }

    function test_RemoveTrustedIssuer_MiddleSwapsLast() public {
        _addThree();

        registry.removeTrustedIssuer(issuer2);

        assertFalse(registry.isTrustedIssuer(issuer2));
        assertEq(registry.getIssuerClaimTopics(issuer2).length, 0);
        assertEq(registry.getTrustedIssuersCount(), 2);
        address[] memory list = registry.getTrustedIssuers();
        assertEq(list[0], issuer1);
        assertEq(list[1], issuer3);
        _assertNoHoles();
    }

    function test_RemoveTrustedIssuer_LastDoesNotMoveAnything() public {
        _addThree();

        registry.removeTrustedIssuer(issuer3);

        assertFalse(registry.isTrustedIssuer(issuer3));
        assertEq(registry.getTrustedIssuersCount(), 2);
        address[] memory list = registry.getTrustedIssuers();
        assertEq(list[0], issuer1);
        assertEq(list[1], issuer2);
        _assertNoHoles();
    }

    function test_RemoveTrustedIssuer_SingleLeavesEmptyList() public {
        registry.addTrustedIssuer(issuer1, _oneTopic(1));

        registry.removeTrustedIssuer(issuer1);

        assertEq(registry.getTrustedIssuersCount(), 0);
        assertEq(registry.getTrustedIssuers().length, 0);
        assertFalse(registry.isTrustedIssuer(issuer1));
    }

    function test_RemoveTrustedIssuer_CanRemoveAll() public {
        _addThree();

        registry.removeTrustedIssuer(issuer1);
        registry.removeTrustedIssuer(issuer2);
        registry.removeTrustedIssuer(issuer3);

        assertEq(registry.getTrustedIssuersCount(), 0);
        assertFalse(registry.isTrustedIssuer(issuer1));
        assertFalse(registry.isTrustedIssuer(issuer2));
        assertFalse(registry.isTrustedIssuer(issuer3));
    }

    function test_RemoveTrustedIssuer_RevertWhen_NotTrusted() public {
        vm.expectRevert("Issuer not trusted");
        registry.removeTrustedIssuer(issuer1);
    }

    function test_RemoveTrustedIssuer_RevertWhen_ZeroAddress() public {
        vm.expectRevert("Issuer not trusted");
        registry.removeTrustedIssuer(address(0));
    }

    function test_RemoveTrustedIssuer_RevertWhen_AlreadyRemoved() public {
        registry.addTrustedIssuer(issuer1, _oneTopic(1));
        registry.removeTrustedIssuer(issuer1);

        vm.expectRevert("Issuer not trusted");
        registry.removeTrustedIssuer(issuer1);
    }

    function test_RemoveTrustedIssuer_RevertWhen_NotOwner() public {
        registry.addTrustedIssuer(issuer1, _oneTopic(1));

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.removeTrustedIssuer(issuer1);
    }

    // ---------------------------------------------------------------------
    // updateIssuerClaimTopics
    // ---------------------------------------------------------------------

    function test_UpdateIssuerClaimTopics() public {
        registry.addTrustedIssuer(issuer1, _oneTopic(1));
        uint256[] memory updated = _twoTopics(7, 8);

        vm.expectEmit(true, false, false, true, address(registry));
        emit ClaimTopicsUpdated(issuer1, updated);

        registry.updateIssuerClaimTopics(issuer1, updated);

        _assertTopicsEq(registry.getIssuerClaimTopics(issuer1), updated);
        assertTrue(registry.hasClaimTopic(issuer1, 7));
        assertTrue(registry.hasClaimTopic(issuer1, 8));
        assertFalse(registry.hasClaimTopic(issuer1, 1));
        assertTrue(registry.isTrustedIssuer(issuer1));
        assertEq(registry.getTrustedIssuersCount(), 1);
    }

    function test_UpdateIssuerClaimTopics_RevertWhen_NotTrusted() public {
        vm.expectRevert("Issuer not trusted");
        registry.updateIssuerClaimTopics(issuer1, _oneTopic(1));
    }

    function test_UpdateIssuerClaimTopics_RevertWhen_NoClaimTopics() public {
        registry.addTrustedIssuer(issuer1, _oneTopic(1));
        uint256[] memory empty = new uint256[](0);

        vm.expectRevert("Must specify at least one claim topic");
        registry.updateIssuerClaimTopics(issuer1, empty);
    }

    function test_UpdateIssuerClaimTopics_RevertWhen_NotOwner() public {
        registry.addTrustedIssuer(issuer1, _oneTopic(1));

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.updateIssuerClaimTopics(issuer1, _twoTopics(3, 4));
    }

    // ---------------------------------------------------------------------
    // Vistas
    // ---------------------------------------------------------------------

    function test_IsTrustedIssuer_FalseWhenUnknown() public view {
        assertFalse(registry.isTrustedIssuer(issuer1));
    }

    function test_GetIssuerClaimTopics_EmptyWhenUnknown() public view {
        assertEq(registry.getIssuerClaimTopics(issuer1).length, 0);
    }

    function test_HasClaimTopic_FalseWhenIssuerUnknown() public view {
        assertFalse(registry.hasClaimTopic(issuer1, 1));
    }

    function test_HasClaimTopic_FalseWhenTopicNotListed() public {
        registry.addTrustedIssuer(issuer1, _twoTopics(1, 2));

        assertFalse(registry.hasClaimTopic(issuer1, 3));
        assertTrue(registry.hasClaimTopic(issuer1, 1));
        assertTrue(registry.hasClaimTopic(issuer1, 2));
    }

    function test_GetTrustedIssuersCount_ZeroOnEmpty() public view {
        assertEq(registry.getTrustedIssuersCount(), 0);
    }

    function test_GetTrustedIssuers_EmptyOnEmpty() public view {
        assertEq(registry.getTrustedIssuers().length, 0);
    }

    // ---------------------------------------------------------------------
    // Fuzz
    // ---------------------------------------------------------------------

    function testFuzz_AddThenRemoveAll_LeavesNoHoles(uint8 rawN) public {
        uint256 n = bound(uint256(rawN), 1, 20);
        _addMany(n);

        assertEq(registry.getTrustedIssuersCount(), n);
        _assertNoHoles();

        while (registry.getTrustedIssuersCount() > 0) {
            address victim = registry.getTrustedIssuers()[0];
            uint256 before = registry.getTrustedIssuersCount();

            registry.removeTrustedIssuer(victim);

            assertEq(registry.getTrustedIssuersCount(), before - 1);
            assertFalse(registry.isTrustedIssuer(victim));
            assertEq(registry.getIssuerClaimTopics(victim).length, 0);
            _assertNoHoles();
        }

        assertEq(registry.getTrustedIssuersCount(), 0);
    }

    function testFuzz_RemoveAtArbitraryIndex_SwapsLast(uint8 rawN, uint8 rawK) public {
        uint256 n = bound(uint256(rawN), 1, 15);
        _addMany(n);

        address[] memory before = registry.getTrustedIssuers();
        uint256 k = bound(uint256(rawK), 0, n - 1);
        address victim = before[k];

        registry.removeTrustedIssuer(victim);

        assertEq(registry.getTrustedIssuersCount(), n - 1);
        assertFalse(registry.isTrustedIssuer(victim));

        if (k < n - 1) {
            assertEq(registry.getTrustedIssuers()[k], before[n - 1]);
        }
        _assertNoHoles();
    }

    function testFuzz_HasClaimTopic(uint256 storedTopic, uint256 queriedTopic) public {
        uint256[] memory topics = new uint256[](1);
        topics[0] = storedTopic;
        registry.addTrustedIssuer(issuer1, topics);

        assertEq(registry.hasClaimTopic(issuer1, queriedTopic), queriedTopic == storedTopic);
        assertEq(registry.hasClaimTopic(issuer2, queriedTopic), false);
    }

    function testFuzz_UpdateTopics(uint256 topicA, uint256 topicB) public {
        registry.addTrustedIssuer(issuer1, _oneTopic(1));

        registry.updateIssuerClaimTopics(issuer1, _twoTopics(topicA, topicB));

        uint256[] memory expected = _twoTopics(topicA, topicB);
        _assertTopicsEq(registry.getIssuerClaimTopics(issuer1), expected);
        assertEq(registry.isTrustedIssuer(issuer1), true);
        assertEq(registry.getTrustedIssuersCount(), 1);
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _addThree() internal {
        registry.addTrustedIssuer(issuer1, _twoTopics(1, 2));
        registry.addTrustedIssuer(issuer2, _twoTopics(3, 4));
        registry.addTrustedIssuer(issuer3, _twoTopics(5, 6));
    }

    function _addMany(uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            registry.addTrustedIssuer(address(uint160(0x1000 + i)), _twoTopics(i + 1, i + 100));
        }
    }

    function _oneTopic(uint256 a) internal pure returns (uint256[] memory topics) {
        topics = new uint256[](1);
        topics[0] = a;
    }

    function _twoTopics(uint256 a, uint256 b) internal pure returns (uint256[] memory topics) {
        topics = new uint256[](2);
        topics[0] = a;
        topics[1] = b;
    }

    function _assertTopicsEq(uint256[] memory actual, uint256[] memory expected) internal {
        assertEq(actual.length, expected.length);
        for (uint256 i = 0; i < expected.length; i++) {
            assertEq(actual[i], expected[i]);
        }
    }

    function _assertNoHoles() internal {
        address[] memory list = registry.getTrustedIssuers();
        for (uint256 i = 0; i < list.length; i++) {
            address a = list[i];
            assertTrue(a != address(0));
            assertTrue(registry.isTrustedIssuer(a));
            assertGt(registry.getIssuerClaimTopics(a).length, 0);
            for (uint256 j = i + 1; j < list.length; j++) {
                assertTrue(a != list[j]);
            }
        }
    }
}
