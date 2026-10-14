// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MaxBalanceCompliance} from "../src/compliance/MaxBalanceCompliance.sol";

contract MockToken {
    mapping(address => uint256) public balances;

    function setBalance(address account, uint256 balance) external {
        balances[account] = balance;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}

contract MaxBalanceComplianceTest is Test {
    MaxBalanceCompliance public compliance;
    MockToken public token;

    address public owner;
    address public user1;
    address public user2;

    uint256 constant MAX_BALANCE = 1000 * 10 ** 18; // 1000 tokens

    event MaxBalanceSet(uint256 maxBalance);
    event TokenContractSet(address indexed tokenContract);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy mock token
        token = new MockToken();

        // Deploy compliance module
        compliance = new MaxBalanceCompliance(owner, MAX_BALANCE);

        // Set token contract
        compliance.setTokenContract(address(token));
    }

    function test_Constructor() public {
        assertEq(compliance.maxBalance(), MAX_BALANCE);
        assertEq(compliance.owner(), owner);
        assertEq(compliance.tokenContract(), address(token));
    }

    function test_SetTokenContract() public {
        // H-19: la vinculacion es unica; se prueba sobre un modulo sin vincular.
        MaxBalanceCompliance fresh = new MaxBalanceCompliance(owner, MAX_BALANCE);
        address newToken = makeAddr("newToken");
        fresh.setTokenContract(newToken);
        assertEq(fresh.tokenContract(), newToken);
    }

    /// QW-8 (H-34): `setTokenContract` emite `TokenContractSet` con el token vinculado.
    function test_QW8_SetTokenContract_emite_evento() public {
        MaxBalanceCompliance fresh = new MaxBalanceCompliance(owner, MAX_BALANCE);
        address newToken = makeAddr("newTokenQW8");
        vm.expectEmit(true, true, true, true);
        emit TokenContractSet(newToken);
        fresh.setTokenContract(newToken);
        assertEq(fresh.tokenContract(), newToken);
    }

    /// H-19: un modulo ya vinculado **no** puede re-vincularse a otro token.
    function test_H19_SetTokenContract_revinculacion_revierte() public {
        address otherToken = makeAddr("otherTokenH19");
        vm.expectRevert("Module already bound to another token");
        compliance.setTokenContract(otherToken);
        assertEq(compliance.tokenContract(), address(token), "la vinculacion no cambia");
    }

    /// H-19: re-fijar el mismo token es idempotente.
    function test_H19_SetTokenContract_mismo_token_idempotente() public {
        compliance.setTokenContract(address(token));
        assertEq(compliance.tokenContract(), address(token));
    }

    function test_RevertWhen_SetTokenContractInvalidAddress() public {
        vm.expectRevert("Invalid token address");
        compliance.setTokenContract(address(0));
    }

    function test_RevertWhen_SetTokenContractNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        compliance.setTokenContract(address(token));
    }

    function test_SetMaxBalance() public {
        uint256 newMaxBalance = 2000 * 10 ** 18;

        vm.expectEmit(true, true, true, true);
        emit MaxBalanceSet(newMaxBalance);

        compliance.setMaxBalance(newMaxBalance);
        assertEq(compliance.maxBalance(), newMaxBalance);
    }

    function test_RevertWhen_SetMaxBalanceNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        compliance.setMaxBalance(2000 * 10 ** 18);
    }

    function test_CanTransfer_WhenUnderMaxBalance() public {
        // User2 has 500 tokens
        token.setBalance(user2, 500 * 10 ** 18);

        // Transferring 400 more should be allowed (total would be 900)
        bool canTransfer = compliance.canTransfer(user1, user2, 400 * 10 ** 18);
        assertTrue(canTransfer);
    }

    function test_CanTransfer_WhenExactlyAtMaxBalance() public {
        // User2 has 500 tokens
        token.setBalance(user2, 500 * 10 ** 18);

        // Transferring 500 more should be allowed (total would be 1000)
        bool canTransfer = compliance.canTransfer(user1, user2, 500 * 10 ** 18);
        assertTrue(canTransfer);
    }

    function test_CanTransfer_FailsWhenExceedsMaxBalance() public {
        // User2 has 900 tokens
        token.setBalance(user2, 900 * 10 ** 18);

        // Transferring 200 more should fail (total would be 1100)
        bool canTransfer = compliance.canTransfer(user1, user2, 200 * 10 ** 18);
        assertFalse(canTransfer);
    }

    function test_CanTransfer_FailsWhenRecipientAlreadyAtMax() public {
        // User2 already has max balance
        token.setBalance(user2, MAX_BALANCE);

        // Any transfer should fail
        bool canTransfer = compliance.canTransfer(user1, user2, 1);
        assertFalse(canTransfer);
    }

    function test_CanTransfer_WhenRecipientHasZeroBalance() public {
        // User2 has no tokens
        token.setBalance(user2, 0);

        // Transferring max amount should be allowed
        bool canTransfer = compliance.canTransfer(user1, user2, MAX_BALANCE);
        assertTrue(canTransfer);
    }

    function testFuzz_CanTransfer(uint256 currentBalance, uint256 transferAmount) public {
        // Bound to reasonable values
        currentBalance = bound(currentBalance, 0, MAX_BALANCE * 2);
        transferAmount = bound(transferAmount, 1, MAX_BALANCE * 2);

        token.setBalance(user2, currentBalance);

        bool canTransfer = compliance.canTransfer(user1, user2, transferAmount);
        bool expected = (currentBalance + transferAmount) <= MAX_BALANCE;

        assertEq(canTransfer, expected);
    }

    function test_TransferredCallback() public {
        // transferred() should not revert (no-op function)
        compliance.transferred(user1, user2, 100 * 10 ** 18);
    }

    function test_CreatedCallback() public {
        // created() should not revert (no-op function)
        compliance.created(user1, 100 * 10 ** 18);
    }

    function test_DestroyedCallback() public {
        // destroyed() should not revert (no-op function)
        compliance.destroyed(user1, 100 * 10 ** 18);
    }

    // ============ AF-01: lectura defensiva del saldo ============

    /// @notice AF-01: sin `tokenContract` configurado, `canTransfer` degrada a `false` sin revertir.
    function test_AF01_canTransfer_sin_tokenContract_degrada_a_false_sin_revert() public {
        MaxBalanceCompliance fresh = new MaxBalanceCompliance(owner, MAX_BALANCE);
        assertEq(fresh.tokenContract(), address(0), "precondicion: sin tokenContract");

        // Antes: `abi.decode` sobre retorno vacio revertia (Panic). Ahora: false, sin revert.
        bool allowed = fresh.canTransfer(user1, user2, 1);
        assertFalse(allowed, "fail-closed sin tokenContract");
    }

    /// @notice AF-01: con `tokenContract` apuntando a una cuenta sin `balanceOf` tampoco revierte.
    function test_AF01_canTransfer_tokenContract_sin_codigo_degrada_a_false_sin_revert() public {
        MaxBalanceCompliance fresh = new MaxBalanceCompliance(owner, MAX_BALANCE);
        fresh.setTokenContract(makeAddr("eoaSinBalanceOf"));

        bool allowed = fresh.canTransfer(user1, user2, 1);
        assertFalse(allowed, "fail-closed si el token no responde");
    }
}
