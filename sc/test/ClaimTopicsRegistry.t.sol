// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ClaimTopicsRegistry} from "../src/ClaimTopicsRegistry.sol";

/// @dev Suite dedicada de `ClaimTopicsRegistry` (Ciclo 1b).
/// Cubre todas las funciones externas, control de acceso, caminos de revierte,
/// eventos, vistas, borrado con swap-and-pop y fuzz.
contract ClaimTopicsRegistryTest is Test {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ClaimTopicAdded(uint256 indexed claimTopic);
    event ClaimTopicRemoved(uint256 indexed claimTopic);

    ClaimTopicsRegistry internal registry;

    address internal owner;
    address internal nonOwner;

    function setUp() public {
        owner = address(this);
        nonOwner = makeAddr("nonOwner");

        registry = new ClaimTopicsRegistry(owner);
    }

    // ---------------------------------------------------------------------
    // Constructor / Ownable
    // ---------------------------------------------------------------------

    function test_Constructor_SetsInitialOwner() public {
        ClaimTopicsRegistry fresh = new ClaimTopicsRegistry(nonOwner);
        assertEq(fresh.owner(), nonOwner);
    }

    function test_Constructor_EmitsOwnershipTransferred() public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(0), nonOwner);
        new ClaimTopicsRegistry(nonOwner);
    }

    function test_Constructor_RevertWhen_OwnerIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new ClaimTopicsRegistry(address(0));
    }

    // ---------------------------------------------------------------------
    // addClaimTopic
    // ---------------------------------------------------------------------

    function test_AddClaimTopic() public {
        vm.expectEmit(true, false, false, true, address(registry));
        emit ClaimTopicAdded(1);

        registry.addClaimTopic(1);

        assertTrue(registry.claimTopicExists(1));
        assertEq(registry.getClaimTopicsCount(), 1);
        assertEq(registry.getClaimTopics().length, 1);
        assertEq(registry.getClaimTopics()[0], 1);
    }

    function test_AddClaimTopic_MultipleKeepsInsertionOrder() public {
        registry.addClaimTopic(1);
        registry.addClaimTopic(2);
        registry.addClaimTopic(3);

        assertEq(registry.getClaimTopicsCount(), 3);
        uint256[] memory topics = registry.getClaimTopics();
        assertEq(topics[0], 1);
        assertEq(topics[1], 2);
        assertEq(topics[2], 3);
        _assertNoHoles();
    }

    /// @dev El contrato NO rechaza el topic 0 (no hay `require(_claimTopic != 0)`).
    /// Se documenta el comportamiento real en el informe, sin modificarlo.
    function test_AddClaimTopic_AcceptsZeroValue() public {
        registry.addClaimTopic(0);

        assertTrue(registry.claimTopicExists(0));
        assertEq(registry.getClaimTopicsCount(), 1);
        assertEq(registry.getClaimTopics()[0], 0);
    }

    function test_AddClaimTopic_RevertWhen_Duplicate() public {
        registry.addClaimTopic(1);

        vm.expectRevert("Claim topic already exists");
        registry.addClaimTopic(1);
    }

    function test_AddClaimTopic_RevertWhen_NotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.addClaimTopic(1);
    }

    // ---------------------------------------------------------------------
    // removeClaimTopic (swap-and-pop)
    // ---------------------------------------------------------------------

    function test_RemoveClaimTopic() public {
        registry.addClaimTopic(1);

        vm.expectEmit(true, false, false, true, address(registry));
        emit ClaimTopicRemoved(1);

        registry.removeClaimTopic(1);

        assertFalse(registry.claimTopicExists(1));
        assertEq(registry.getClaimTopicsCount(), 0);
        assertEq(registry.getClaimTopics().length, 0);
    }

    function test_RemoveClaimTopic_FirstSwapsLast() public {
        _addThree();

        registry.removeClaimTopic(1);

        assertFalse(registry.claimTopicExists(1));
        assertEq(registry.getClaimTopicsCount(), 2);
        uint256[] memory topics = registry.getClaimTopics();
        assertEq(topics[0], 3); // el último ocupa el hueco
        assertEq(topics[1], 2);
        assertTrue(registry.claimTopicExists(2));
        assertTrue(registry.claimTopicExists(3));
        _assertNoHoles();
    }

    function test_RemoveClaimTopic_MiddleSwapsLast() public {
        _addThree();

        registry.removeClaimTopic(2);

        assertFalse(registry.claimTopicExists(2));
        assertEq(registry.getClaimTopicsCount(), 2);
        uint256[] memory topics = registry.getClaimTopics();
        assertEq(topics[0], 1);
        assertEq(topics[1], 3);
        _assertNoHoles();
    }

    function test_RemoveClaimTopic_LastDoesNotMoveAnything() public {
        _addThree();

        registry.removeClaimTopic(3);

        assertFalse(registry.claimTopicExists(3));
        assertEq(registry.getClaimTopicsCount(), 2);
        uint256[] memory topics = registry.getClaimTopics();
        assertEq(topics[0], 1);
        assertEq(topics[1], 2);
        _assertNoHoles();
    }

    function test_RemoveClaimTopic_CanRemoveAll() public {
        _addThree();

        registry.removeClaimTopic(1);
        registry.removeClaimTopic(2);
        registry.removeClaimTopic(3);

        assertEq(registry.getClaimTopicsCount(), 0);
        assertFalse(registry.claimTopicExists(1));
        assertFalse(registry.claimTopicExists(2));
        assertFalse(registry.claimTopicExists(3));
    }

    function test_RemoveClaimTopic_CanReAddAfterRemoval() public {
        registry.addClaimTopic(1);
        registry.removeClaimTopic(1);
        assertEq(registry.getClaimTopicsCount(), 0);

        registry.addClaimTopic(1);

        assertTrue(registry.claimTopicExists(1));
        assertEq(registry.getClaimTopicsCount(), 1);
    }

    function test_RemoveClaimTopic_RevertWhen_DoesNotExist() public {
        vm.expectRevert("Claim topic does not exist");
        registry.removeClaimTopic(1);
    }

    function test_RemoveClaimTopic_RevertWhen_EmptyRegistry() public {
        vm.expectRevert("Claim topic does not exist");
        registry.removeClaimTopic(0);
    }

    function test_RemoveClaimTopic_RevertWhen_AlreadyRemoved() public {
        registry.addClaimTopic(1);
        registry.removeClaimTopic(1);

        vm.expectRevert("Claim topic does not exist");
        registry.removeClaimTopic(1);
    }

    function test_RemoveClaimTopic_RevertWhen_NotOwner() public {
        registry.addClaimTopic(1);

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.removeClaimTopic(1);
    }

    // ---------------------------------------------------------------------
    // Vistas
    // ---------------------------------------------------------------------

    function test_ClaimTopicExists_FalseWhenUnknown() public view {
        assertFalse(registry.claimTopicExists(1));
        assertFalse(registry.claimTopicExists(0));
    }

    function test_GetClaimTopicsCount_ZeroOnEmpty() public view {
        assertEq(registry.getClaimTopicsCount(), 0);
    }

    function test_GetClaimTopics_EmptyOnEmpty() public view {
        assertEq(registry.getClaimTopics().length, 0);
    }

    // ---------------------------------------------------------------------
    // Fuzz
    // ---------------------------------------------------------------------

    function testFuzz_AddThenRemoveAll_LeavesNoHoles(uint8 rawN) public {
        uint256 n = bound(uint256(rawN), 1, 30);
        _addMany(n);

        assertEq(registry.getClaimTopicsCount(), n);
        _assertNoHoles();

        while (registry.getClaimTopicsCount() > 0) {
            uint256 victim = registry.getClaimTopics()[0];
            uint256 before = registry.getClaimTopicsCount();

            registry.removeClaimTopic(victim);

            assertEq(registry.getClaimTopicsCount(), before - 1);
            assertFalse(registry.claimTopicExists(victim));
            _assertNoHoles();
        }

        assertEq(registry.getClaimTopicsCount(), 0);
    }

    function testFuzz_RemoveAtArbitraryIndex_SwapsLast(uint8 rawN, uint8 rawK) public {
        uint256 n = bound(uint256(rawN), 1, 25);
        _addMany(n);

        uint256[] memory before = registry.getClaimTopics();
        uint256 k = bound(uint256(rawK), 0, n - 1);
        uint256 victim = before[k];

        registry.removeClaimTopic(victim);

        assertEq(registry.getClaimTopicsCount(), n - 1);
        assertFalse(registry.claimTopicExists(victim));

        if (k < n - 1) {
            assertEq(registry.getClaimTopics()[k], before[n - 1]);
        }
        _assertNoHoles();
    }

    function testFuzz_ClaimTopicExists(uint256 added) public {
        assertFalse(registry.claimTopicExists(added));

        registry.addClaimTopic(added);
        assertTrue(registry.claimTopicExists(added));

        registry.removeClaimTopic(added);
        assertFalse(registry.claimTopicExists(added));
    }

    function testFuzz_AddDistinctTopics(uint8 rawN) public {
        uint256 n = bound(uint256(rawN), 1, 30);
        _addMany(n);

        uint256[] memory topics = registry.getClaimTopics();
        for (uint256 i = 0; i < n; i++) {
            assertTrue(registry.claimTopicExists(i + 1));
            assertEq(topics[i], i + 1);
        }
        assertEq(registry.getClaimTopicsCount(), n);
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _addThree() internal {
        registry.addClaimTopic(1);
        registry.addClaimTopic(2);
        registry.addClaimTopic(3);
    }

    function _addMany(uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            registry.addClaimTopic(i + 1);
        }
    }

    function _assertNoHoles() internal {
        uint256[] memory topics = registry.getClaimTopics();
        for (uint256 i = 0; i < topics.length; i++) {
            assertTrue(registry.claimTopicExists(topics[i]));
            for (uint256 j = i + 1; j < topics.length; j++) {
                assertTrue(topics[i] != topics[j]);
            }
        }
    }
}
