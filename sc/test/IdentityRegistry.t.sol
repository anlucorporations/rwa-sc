// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";

/// @dev Suite dedicada de `IdentityRegistry` (Ciclo 1b).
/// Cubre todas las funciones externas, control de acceso, caminos de revierte,
/// eventos, vistas, borrado con swap-and-pop y casos límite de estado.
contract IdentityRegistryTest is Test {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event IdentityRegistered(address indexed wallet, address indexed identity);
    event IdentityRemoved(address indexed wallet, address indexed identity);
    event IdentityUpdated(address indexed wallet, address indexed oldIdentity, address indexed newIdentity);

    IdentityRegistry internal registry;

    address internal owner;
    address internal nonOwner;

    address internal wallet1;
    address internal wallet2;
    address internal wallet3;

    address internal identity1;
    address internal identity2;
    address internal identity3;

    function setUp() public {
        owner = address(this);
        nonOwner = makeAddr("nonOwner");

        wallet1 = makeAddr("wallet1");
        wallet2 = makeAddr("wallet2");
        wallet3 = makeAddr("wallet3");

        identity1 = makeAddr("identity1");
        identity2 = makeAddr("identity2");
        identity3 = makeAddr("identity3");

        registry = new IdentityRegistry(owner);
    }

    // ---------------------------------------------------------------------
    // Constructor / Ownable
    // ---------------------------------------------------------------------

    function test_Constructor_SetsInitialOwner() public {
        IdentityRegistry fresh = new IdentityRegistry(nonOwner);
        assertEq(fresh.owner(), nonOwner);
    }

    function test_Constructor_EmitsOwnershipTransferred() public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(0), nonOwner);
        new IdentityRegistry(nonOwner);
    }

    function test_Constructor_RevertWhen_OwnerIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new IdentityRegistry(address(0));
    }

    // ---------------------------------------------------------------------
    // registerIdentity
    // ---------------------------------------------------------------------

    function test_RegisterIdentity() public {
        vm.expectEmit(true, true, false, true, address(registry));
        emit IdentityRegistered(wallet1, identity1);

        registry.registerIdentity(wallet1, identity1);

        assertEq(registry.getIdentity(wallet1), identity1);
        assertTrue(registry.isRegistered(wallet1));
        assertEq(registry.getRegisteredCount(), 1);
        assertEq(registry.getRegisteredAddress(0), wallet1);
    }

    function test_RegisterIdentity_MultipleKeepsInsertionOrder() public {
        registry.registerIdentity(wallet1, identity1);
        registry.registerIdentity(wallet2, identity2);
        registry.registerIdentity(wallet3, identity3);

        assertEq(registry.getRegisteredCount(), 3);
        assertEq(registry.getRegisteredAddress(0), wallet1);
        assertEq(registry.getRegisteredAddress(1), wallet2);
        assertEq(registry.getRegisteredAddress(2), wallet3);
        _assertNoHoles();
    }

    function test_RegisterIdentity_CanReRegisterAfterRemoval() public {
        registry.registerIdentity(wallet1, identity1);
        registry.removeIdentity(wallet1);
        assertEq(registry.getRegisteredCount(), 0);

        registry.registerIdentity(wallet1, identity2);

        assertTrue(registry.isRegistered(wallet1));
        assertEq(registry.getIdentity(wallet1), identity2);
        assertEq(registry.getRegisteredCount(), 1);
        assertEq(registry.getRegisteredAddress(0), wallet1);
    }

    function test_RegisterIdentity_RevertWhen_WalletIsZero() public {
        vm.expectRevert("Invalid wallet address");
        registry.registerIdentity(address(0), identity1);
    }

    function test_RegisterIdentity_RevertWhen_IdentityIsZero() public {
        vm.expectRevert("Invalid identity address");
        registry.registerIdentity(wallet1, address(0));
    }

    function test_RegisterIdentity_RevertWhen_AlreadyRegistered() public {
        registry.registerIdentity(wallet1, identity1);

        vm.expectRevert("Wallet already registered");
        registry.registerIdentity(wallet1, identity2);
    }

    function test_RegisterIdentity_RevertWhen_NotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.registerIdentity(wallet1, identity1);
    }

    // ---------------------------------------------------------------------
    // updateIdentity
    // ---------------------------------------------------------------------

    function test_UpdateIdentity() public {
        registry.registerIdentity(wallet1, identity1);

        vm.expectEmit(true, true, true, true, address(registry));
        emit IdentityUpdated(wallet1, identity1, identity2);

        registry.updateIdentity(wallet1, identity2);

        assertEq(registry.getIdentity(wallet1), identity2);
        assertTrue(registry.isRegistered(wallet1));
        assertEq(registry.getRegisteredCount(), 1);
        assertEq(registry.getRegisteredAddress(0), wallet1);
        _assertNoHoles();
    }

    function test_UpdateIdentity_KeepsOtherEntries() public {
        registry.registerIdentity(wallet1, identity1);
        registry.registerIdentity(wallet2, identity2);

        registry.updateIdentity(wallet1, identity3);

        assertEq(registry.getIdentity(wallet1), identity3);
        assertEq(registry.getIdentity(wallet2), identity2);
        assertEq(registry.getRegisteredCount(), 2);
        assertEq(registry.getRegisteredAddress(0), wallet1);
        assertEq(registry.getRegisteredAddress(1), wallet2);
    }

    function test_UpdateIdentity_RevertWhen_WalletIsZero() public {
        vm.expectRevert("Invalid wallet address");
        registry.updateIdentity(address(0), identity1);
    }

    function test_UpdateIdentity_RevertWhen_IdentityIsZero() public {
        registry.registerIdentity(wallet1, identity1);

        vm.expectRevert("Invalid identity address");
        registry.updateIdentity(wallet1, address(0));
    }

    function test_UpdateIdentity_RevertWhen_NotRegistered() public {
        vm.expectRevert("Wallet not registered");
        registry.updateIdentity(wallet1, identity1);
    }

    function test_UpdateIdentity_RevertWhen_NotOwner() public {
        registry.registerIdentity(wallet1, identity1);

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.updateIdentity(wallet1, identity2);
    }

    // ---------------------------------------------------------------------
    // removeIdentity (swap-and-pop)
    // ---------------------------------------------------------------------

    function test_RemoveIdentity_FirstSwapsLast() public {
        _registerThree();

        vm.expectEmit(true, true, false, true, address(registry));
        emit IdentityRemoved(wallet1, identity1);

        registry.removeIdentity(wallet1);

        assertFalse(registry.isRegistered(wallet1));
        assertEq(registry.getIdentity(wallet1), address(0));
        assertEq(registry.getRegisteredCount(), 2);
        assertEq(registry.getRegisteredAddress(0), wallet3); // el último ocupa el hueco
        assertEq(registry.getRegisteredAddress(1), wallet2);
        _assertNoHoles();
    }

    function test_RemoveIdentity_MiddleSwapsLast() public {
        _registerThree();

        registry.removeIdentity(wallet2);

        assertFalse(registry.isRegistered(wallet2));
        assertEq(registry.getIdentity(wallet2), address(0));
        assertEq(registry.getRegisteredCount(), 2);
        assertEq(registry.getRegisteredAddress(0), wallet1);
        assertEq(registry.getRegisteredAddress(1), wallet3);
        _assertNoHoles();
    }

    function test_RemoveIdentity_LastDoesNotMoveAnything() public {
        _registerThree();

        registry.removeIdentity(wallet3);

        assertFalse(registry.isRegistered(wallet3));
        assertEq(registry.getRegisteredCount(), 2);
        assertEq(registry.getRegisteredAddress(0), wallet1);
        assertEq(registry.getRegisteredAddress(1), wallet2);
        _assertNoHoles();
    }

    function test_RemoveIdentity_SingleLeavesEmptyArray() public {
        registry.registerIdentity(wallet1, identity1);

        registry.removeIdentity(wallet1);

        assertEq(registry.getRegisteredCount(), 0);
        assertFalse(registry.isRegistered(wallet1));
        assertEq(registry.getIdentity(wallet1), address(0));

        vm.expectRevert("Index out of bounds");
        registry.getRegisteredAddress(0);
    }

    function test_RemoveIdentity_CanRemoveAll() public {
        _registerThree();

        registry.removeIdentity(wallet1);
        registry.removeIdentity(wallet2);
        registry.removeIdentity(wallet3);

        assertEq(registry.getRegisteredCount(), 0);
        assertFalse(registry.isRegistered(wallet1));
        assertFalse(registry.isRegistered(wallet2));
        assertFalse(registry.isRegistered(wallet3));
    }

    function test_RemoveIdentity_RevertWhen_NotRegistered() public {
        vm.expectRevert("Wallet not registered");
        registry.removeIdentity(wallet1);
    }

    function test_RemoveIdentity_RevertWhen_ZeroAddress() public {
        vm.expectRevert("Wallet not registered");
        registry.removeIdentity(address(0));
    }

    function test_RemoveIdentity_RevertWhen_AlreadyRemoved() public {
        registry.registerIdentity(wallet1, identity1);
        registry.removeIdentity(wallet1);

        vm.expectRevert("Wallet not registered");
        registry.removeIdentity(wallet1);
    }

    function test_RemoveIdentity_RevertWhen_NotOwner() public {
        registry.registerIdentity(wallet1, identity1);

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner));
        registry.removeIdentity(wallet1);
    }

    // ---------------------------------------------------------------------
    // Vistas
    // ---------------------------------------------------------------------

    function test_GetIdentity_ReturnsZeroWhenUnknown() public view {
        assertEq(registry.getIdentity(wallet1), address(0));
    }

    function test_IsRegistered_FalseWhenUnknown() public view {
        assertFalse(registry.isRegistered(wallet1));
    }

    function test_GetRegisteredCount_ZeroOnEmpty() public view {
        assertEq(registry.getRegisteredCount(), 0);
    }

    function test_GetRegisteredAddress_RevertWhen_Empty() public {
        vm.expectRevert("Index out of bounds");
        registry.getRegisteredAddress(0);
    }

    function test_GetRegisteredAddress_RevertWhen_IndexEqualsLength() public {
        registry.registerIdentity(wallet1, identity1);

        vm.expectRevert("Index out of bounds");
        registry.getRegisteredAddress(1);
    }

    function test_GetRegisteredAddress_RevertWhen_IndexGreaterThanLength() public {
        registry.registerIdentity(wallet1, identity1);
        registry.registerIdentity(wallet2, identity2);

        vm.expectRevert("Index out of bounds");
        registry.getRegisteredAddress(type(uint256).max);
    }

    // ---------------------------------------------------------------------
    // Fuzz
    // ---------------------------------------------------------------------

    function testFuzz_RegisterThenRemoveAll_LeavesNoHoles(uint8 rawN) public {
        uint256 n = bound(uint256(rawN), 1, 25);
        _registerMany(n);

        assertEq(registry.getRegisteredCount(), n);
        _assertNoHoles();

        while (registry.getRegisteredCount() > 0) {
            address victim = registry.getRegisteredAddress(0);
            uint256 before = registry.getRegisteredCount();

            registry.removeIdentity(victim);

            assertEq(registry.getRegisteredCount(), before - 1);
            assertFalse(registry.isRegistered(victim));
            _assertNoHoles();
        }

        assertEq(registry.getRegisteredCount(), 0);
    }

    function testFuzz_RemoveAtArbitraryIndex_SwapsLast(uint8 rawN, uint8 rawK) public {
        uint256 n = bound(uint256(rawN), 1, 20);
        _registerMany(n);

        address[] memory before = _snapshot();
        uint256 k = bound(uint256(rawK), 0, n - 1);
        address victim = before[k];

        registry.removeIdentity(victim);

        assertEq(registry.getRegisteredCount(), n - 1);
        assertFalse(registry.isRegistered(victim));
        assertEq(registry.getIdentity(victim), address(0));

        if (k < n - 1) {
            assertEq(registry.getRegisteredAddress(k), before[n - 1]);
        }
        _assertNoHoles();
    }

    function testFuzz_RegisterIdentity(uint256 walletSeed, uint256 identitySeed) public {
        // Se reserva la dirección cero (revertida por el contrato).
        address wallet = address(uint160(bound(walletSeed, 1, type(uint160).max)));
        address identity = address(uint160(bound(identitySeed, 1, type(uint160).max)));

        registry.registerIdentity(wallet, identity);

        assertTrue(registry.isRegistered(wallet));
        assertEq(registry.getIdentity(wallet), identity);
        assertEq(registry.getRegisteredCount(), 1);
        assertEq(registry.getRegisteredAddress(0), wallet);
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _registerThree() internal {
        registry.registerIdentity(wallet1, identity1);
        registry.registerIdentity(wallet2, identity2);
        registry.registerIdentity(wallet3, identity3);
    }

    function _registerMany(uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            registry.registerIdentity(address(uint160(0x1000 + i)), address(uint160(0x2000 + i)));
        }
    }

    function _snapshot() internal view returns (address[] memory out) {
        uint256 n = registry.getRegisteredCount();
        out = new address[](n);
        for (uint256 i = 0; i < n; i++) {
            out[i] = registry.getRegisteredAddress(i);
        }
    }

    function _assertNoHoles() internal {
        uint256 n = registry.getRegisteredCount();
        for (uint256 i = 0; i < n; i++) {
            address a = registry.getRegisteredAddress(i);
            assertTrue(a != address(0));
            assertTrue(registry.isRegistered(a));
            assertTrue(registry.getIdentity(a) != address(0));
            for (uint256 j = i + 1; j < n; j++) {
                assertTrue(a != registry.getRegisteredAddress(j));
            }
        }
    }
}
