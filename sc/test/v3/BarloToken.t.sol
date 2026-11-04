// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {BarloToken} from "../../src/v3/BarloToken.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @notice Tests de C0 para BarloToken (BRLT): 8 decimales, cap, límites por tx,
///         roles, pausa y quema. Verifican las decisiones D-V3-02 / Q2 / H-26.
contract BarloTokenTest is Test {
    BarloToken internal token;

    address internal admin = address(0xA11CE);
    address internal minter = address(0xB0B);
    address internal pauser = address(0xCAFE);
    address internal alice = address(0xA1);
    address internal bob = address(0xB1);

    uint256 internal constant UNIT = 10 ** 8; // 1 BRLT
    uint256 internal constant CAP = 100_000_000 * UNIT; // 100 M BRLT
    uint256 internal constant MAX_MINT = 10_000 * UNIT; // 10 k BRLT

    function setUp() public {
        token = new BarloToken(admin, CAP, MAX_MINT);
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.PAUSER_ROLE(), pauser);
        vm.stopPrank();
    }

    // --- metadatos -----------------------------------------------------------

    function test_decimals_es_8() public view {
        assertEq(token.decimals(), 8, "BRLT debe tener 8 decimales");
    }

    function test_nombre_y_simbolo() public view {
        assertEq(token.name(), "BarloToken");
        assertEq(token.symbol(), "BRLT");
    }

    function test_cap_inmutable() public view {
        assertEq(token.cap(), CAP);
    }

    // --- emisión -------------------------------------------------------------

    function test_mint_por_minter_dentro_del_limite() public {
        vm.prank(minter);
        token.mint(alice, 1_000 * UNIT);
        assertEq(token.balanceOf(alice), 1_000 * UNIT);
        assertEq(token.totalSupply(), 1_000 * UNIT);
    }

    function test_mint_revierte_sin_rol() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, token.MINTER_ROLE()
            )
        );
        vm.prank(alice);
        token.mint(alice, UNIT);
    }

    function test_mint_revierte_superando_max_por_tx() public {
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(BarloToken.MaxMintPerTxExceeded.selector, MAX_MINT + 1, MAX_MINT)
        );
        token.mint(alice, MAX_MINT + 1);
    }

    function test_mint_revierte_superando_cap() public {
        // Con el límite por tx por defecto se necesitan varias emisiones para acercarse al cap.
        vm.startPrank(admin);
        token.setMaxMintPerTx(CAP);
        vm.stopPrank();

        vm.prank(minter);
        token.mint(alice, CAP);
        assertEq(token.totalSupply(), CAP);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(BarloToken.CapExceeded.selector, 1, 0));
        token.mint(bob, 1);
    }

    function test_mint_revierte_cantidad_cero() public {
        vm.prank(minter);
        vm.expectRevert(BarloToken.ZeroAmount.selector);
        token.mint(alice, 0);
    }

    function test_mint_revierte_direccion_cero() public {
        vm.prank(minter);
        vm.expectRevert(BarloToken.ZeroAddress.selector);
        token.mint(address(0), UNIT);
    }

    function test_admin_puede_actualizar_max_mint() public {
        vm.prank(admin);
        token.setMaxMintPerTx(5_000 * UNIT);
        assertEq(token.maxMintPerTx(), 5_000 * UNIT);
    }

    function test_no_admin_no_puede_actualizar_max_mint() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, token.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(alice);
        token.setMaxMintPerTx(5_000 * UNIT);
    }

    // --- quema ---------------------------------------------------------------

    function test_burn_reduce_suministro() public {
        vm.prank(minter);
        token.mint(alice, 100 * UNIT);

        vm.prank(alice);
        token.burn(40 * UNIT);
        assertEq(token.balanceOf(alice), 60 * UNIT);
        assertEq(token.totalSupply(), 60 * UNIT);
    }

    function test_burnFrom_con_allowance() public {
        vm.prank(minter);
        token.mint(alice, 100 * UNIT);

        vm.prank(alice);
        token.approve(bob, 30 * UNIT);

        vm.prank(bob);
        token.burnFrom(alice, 30 * UNIT);
        assertEq(token.balanceOf(alice), 70 * UNIT);
    }

    // --- pausa ---------------------------------------------------------------

    function test_pausa_bloquea_transferencia_mint_y_burn() public {
        vm.prank(minter);
        token.mint(alice, 100 * UNIT);

        vm.prank(pauser);
        token.pause();
        assertTrue(token.paused());

        vm.prank(alice);
        vm.expectRevert(BarloToken.TokenPaused.selector);
        token.transfer(bob, 1 * UNIT);

        vm.prank(minter);
        vm.expectRevert(BarloToken.TokenPaused.selector);
        token.mint(alice, UNIT);

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(alice);
        token.burn(UNIT);
    }

    function test_unpause_restaura_transferencias() public {
        vm.prank(minter);
        token.mint(alice, 100 * UNIT);

        vm.prank(pauser);
        token.pause();
        vm.prank(pauser);
        token.unpause();

        vm.prank(alice);
        token.transfer(bob, 10 * UNIT);
        assertEq(token.balanceOf(bob), 10 * UNIT);
    }

    function test_pausa_solo_pauser() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, token.PAUSER_ROLE()
            )
        );
        vm.prank(alice);
        token.pause();
    }

    // --- fuzz ----------------------------------------------------------------

    function testFuzz_mint_respeta_limite_por_tx(uint256 amount) public {
        amount = bound(amount, 1, MAX_MINT);
        vm.prank(minter);
        token.mint(alice, amount);
        assertEq(token.balanceOf(alice), amount);
    }

    function testFuzz_mint_por_encima_del_limite_revierte(uint256 amount) public {
        amount = bound(amount, MAX_MINT + 1, type(uint128).max);
        vm.prank(minter);
        vm.expectRevert();
        token.mint(alice, amount);
    }
}

/// @notice Tests adicionales de C0: ramas de validación del constructor y del límite por tx.
contract BarloTokenConstructorTest is Test {
    uint256 internal constant CAP = 100_000_000 * 10 ** 8;
    uint256 internal constant MAX_MINT = 10_000 * 10 ** 8;

    function test_constructor_revierte_admin_cero() public {
        vm.expectRevert(BarloToken.ZeroAddress.selector);
        new BarloToken(address(0), CAP, MAX_MINT);
    }

    function test_constructor_revierte_cap_cero() public {
        vm.expectRevert(BarloToken.InvalidCap.selector);
        new BarloToken(address(0xA11CE), 0, MAX_MINT);
    }

    function test_constructor_revierte_max_mint_cero() public {
        vm.expectRevert(BarloToken.InvalidMaxMintPerTx.selector);
        new BarloToken(address(0xA11CE), CAP, 0);
    }

    function test_constructor_revierte_max_mint_mayor_que_cap() public {
        vm.expectRevert(BarloToken.InvalidMaxMintPerTx.selector);
        new BarloToken(address(0xA11CE), CAP, CAP + 1);
    }

    function test_admin_no_puede_fijar_max_mint_cero() public {
        BarloToken token = new BarloToken(address(0xA11CE), CAP, MAX_MINT);
        vm.expectRevert(BarloToken.InvalidMaxMintPerTx.selector);
        vm.prank(address(0xA11CE));
        token.setMaxMintPerTx(0);
    }

    function test_admin_no_puede_fijar_max_mint_mayor_que_cap() public {
        BarloToken token = new BarloToken(address(0xA11CE), CAP, MAX_MINT);
        vm.expectRevert(BarloToken.InvalidMaxMintPerTx.selector);
        vm.prank(address(0xA11CE));
        token.setMaxMintPerTx(CAP + 1);
    }
}
