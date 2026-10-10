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

        // HB-13: la identidad registrada debe ser un contrato. Se dota de código mínimo (STOP)
        // a las direcciones deterministas de esta suite para conservar su intención (bookkeeping
        // del registry) sin convertir cada caso en un despliegue completo.
        _asContract(identity1);
        _asContract(identity2);
        _asContract(identity3);

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
        // Se reservan la dirección cero (revertida por el contrato) y los precompiles
        // (no se puede escribir código con `vm.etch` en 0x01..0x0a).
        address wallet = address(uint160(bound(walletSeed, 0x100, type(uint160).max)));
        address identity = address(uint160(bound(identitySeed, 0x100, type(uint160).max)));

        // HB-13: la identidad debe tener código para superar la validación.
        _asContract(identity);

        registry.registerIdentity(wallet, identity);

        assertTrue(registry.isRegistered(wallet));
        assertEq(registry.getIdentity(wallet), identity);
        assertEq(registry.getRegisteredCount(), 1);
        assertEq(registry.getRegisteredAddress(0), wallet);
    }

    // ---------------------------------------------------------------------
    // HB-13 (Ciclo 4): la identidad registrada debe ser un contrato
    // ---------------------------------------------------------------------

    function test_HB13_RegisterIdentity_ContractOk() public {
        address identity = address(uint160(0xC0DE));
        _asContract(identity);

        registry.registerIdentity(wallet1, identity);

        assertEq(registry.getIdentity(wallet1), identity);
        assertTrue(registry.isRegistered(wallet1));
    }

    function test_HB13_RegisterIdentity_RevertWhen_Eoa() public {
        address eoa = makeAddr("eoaIdentity");

        vm.expectRevert("Identity must be a contract");
        registry.registerIdentity(wallet1, eoa);

        assertFalse(registry.isRegistered(wallet1));
        assertEq(registry.getRegisteredCount(), 0);
    }

    function test_HB13_UpdateIdentity_ContractOk() public {
        registry.registerIdentity(wallet1, identity1);

        address newIdentity = address(uint160(0xC0DE));
        _asContract(newIdentity);

        registry.updateIdentity(wallet1, newIdentity);

        assertEq(registry.getIdentity(wallet1), newIdentity);
    }

    function test_HB13_UpdateIdentity_RevertWhen_Eoa() public {
        registry.registerIdentity(wallet1, identity1);

        address eoa = makeAddr("eoaIdentity");

        vm.expectRevert("Identity must be a contract");
        registry.updateIdentity(wallet1, eoa);

        assertEq(registry.getIdentity(wallet1), identity1);
    }

    // ---------------------------------------------------------------------
    // HB-14 (Ciclo 8): pertenencia explicita a `registeredAddresses`
    // ---------------------------------------------------------------------

    /// @dev Camino feliz: con mapping y array sincronizados, `removeIdentity` borra por
    /// swap-and-pop y emite `IdentityRemoved` (comportamiento preexistente, ahora respaldado
    /// por la comprobacion explicita de pertenencia).
    function test_HB14_RemoveIdentity_Ok_CuandoPerteneceAlArray() public {
        _registerThree();

        vm.expectEmit(true, true, false, true, address(registry));
        emit IdentityRemoved(wallet2, identity2);

        registry.removeIdentity(wallet2);

        assertFalse(registry.isRegistered(wallet2));
        assertEq(registry.getRegisteredCount(), 2);
        assertEq(registry.getRegisteredAddress(0), wallet1);
        assertEq(registry.getRegisteredAddress(1), wallet3);
        _assertNoHoles();
    }

    /// @dev HB-14: si el mapping `registered` afirma que el wallet esta registrado pero el array
    /// `registeredAddresses` no lo contiene (estado desincronizado, hoy inalcanzable por las rutas
    /// publicas), `removeIdentity` debe revertir en lugar de emitir el evento sin borrar nada.
    /// Se fuerza la desincronizacion directamente en el storage para ejercitar la rama defensiva.
    function test_HB14_RemoveIdentity_RevertWhen_MappingYArrayDesincronizados() public {
        // Slot 2 = `registered` (slot 0 = Ownable._owner, slot 1 = `identities`).
        bytes32 registeredSlot = keccak256(abi.encode(wallet1, uint256(2)));
        vm.store(address(registry), registeredSlot, bytes32(uint256(1)));

        // La premisa de la prueba: el mapping dice "registrado" pero el array esta vacio.
        assertTrue(registry.isRegistered(wallet1), "mapping desincronizado a proposito");
        assertEq(registry.getRegisteredCount(), 0, "el array no contiene al wallet");

        vm.expectRevert("Wallet not in registered addresses");
        registry.removeIdentity(wallet1);

        // El estado no cambia: el require final revierte toda la transaccion.
        assertTrue(registry.isRegistered(wallet1));
        assertEq(registry.getRegisteredCount(), 0);
    }

    /// @dev HB-14 complementario: si el array contiene al wallet pero el mapping no, la primera
    /// comprobacion (`"Wallet not registered"`) sigue siendo la que corta, sin tocar el array.
    function test_HB14_RemoveIdentity_RevertWhen_ArraySinMapping() public {
        _registerThree();

        // Se borra el flag del mapping para wallet1 sin tocar el array (desincronizacion inversa).
        bytes32 registeredSlot = keccak256(abi.encode(wallet1, uint256(2)));
        vm.store(address(registry), registeredSlot, bytes32(uint256(0)));

        assertFalse(registry.isRegistered(wallet1));
        assertEq(registry.getRegisteredCount(), 3, "el array sigue conteniendo al wallet");

        vm.expectRevert("Wallet not registered");
        registry.removeIdentity(wallet1);

        assertEq(registry.getRegisteredCount(), 3);
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    /// @dev HB-13: dota a una dirección de código mínimo (un `STOP`) para satisfacer
    /// `_identity.code.length > 0` conservando las direcciones deterministas de la suite.
    function _asContract(address account) internal {
        vm.etch(account, hex"00");
    }

    function _registerThree() internal {
        registry.registerIdentity(wallet1, identity1);
        registry.registerIdentity(wallet2, identity2);
        registry.registerIdentity(wallet3, identity3);
    }

    function _registerMany(uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            address identity = address(uint160(0x2000 + i));
            _asContract(identity); // HB-13: identidad con código
            registry.registerIdentity(address(uint160(0x1000 + i)), identity);
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
