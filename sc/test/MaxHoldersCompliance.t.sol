// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MaxHoldersCompliance} from "../src/compliance/MaxHoldersCompliance.sol";

contract MockToken {
    mapping(address => uint256) public balances;

    function setBalance(address account, uint256 balance) external {
        balances[account] = balance;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}

contract MaxHoldersComplianceTest is Test {
    MaxHoldersCompliance public compliance;
    MockToken public token;

    address public owner;
    address public user1;
    address public user2;
    address public user3;

    uint256 constant MAX_HOLDERS = 10;

    event MaxHoldersSet(uint256 maxHolders);
    event HolderAdded(address indexed holder);
    event HolderRemoved(address indexed holder);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Deploy mock token
        token = new MockToken();

        // Deploy compliance module
        compliance = new MaxHoldersCompliance(owner, MAX_HOLDERS);

        // Set token contract
        compliance.setTokenContract(address(token));
    }

    function test_Constructor() public {
        assertEq(compliance.maxHolders(), MAX_HOLDERS);
        assertEq(compliance.holderCount(), 0);
        assertEq(compliance.owner(), owner);
        assertEq(compliance.tokenContract(), address(token));
    }

    function test_SetTokenContract() public {
        address newToken = makeAddr("newToken");
        compliance.setTokenContract(newToken);
        assertEq(compliance.tokenContract(), newToken);
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

    function test_SetMaxHolders() public {
        uint256 newMaxHolders = 20;

        vm.expectEmit(true, true, true, true);
        emit MaxHoldersSet(newMaxHolders);

        compliance.setMaxHolders(newMaxHolders);
        assertEq(compliance.maxHolders(), newMaxHolders);
    }

    function test_RevertWhen_SetMaxHoldersBelowCurrentCount() public {
        // Add some holders first
        vm.startPrank(address(token));
        token.setBalance(user1, 100);
        compliance.created(user1, 100);
        vm.stopPrank();

        assertEq(compliance.holderCount(), 1);

        // Try to set max holders below current count
        vm.expectRevert("Cannot set below current holder count");
        compliance.setMaxHolders(0);
    }

    function test_RevertWhen_SetMaxHoldersNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        compliance.setMaxHolders(20);
    }

    function test_CanTransfer_ToExistingHolder() public {
        // Add user2 as holder
        vm.startPrank(address(token));
        token.setBalance(user2, 100);
        compliance.created(user2, 100);
        vm.stopPrank();

        // Transfer to existing holder should be allowed
        bool canTransfer = compliance.canTransfer(user1, user2, 50);
        assertTrue(canTransfer);
    }

    function test_CanTransfer_ToNewHolder_WhenUnderLimit() public {
        // No holders yet, should be allowed
        bool canTransfer = compliance.canTransfer(user1, user2, 100);
        assertTrue(canTransfer);
    }

    function test_CanTransfer_FailsWhenMaxHoldersReached() public {
        // Fill up to max holders
        vm.startPrank(address(token));
        for (uint256 i = 0; i < MAX_HOLDERS; i++) {
            address holder = address(uint160(i + 1000));
            token.setBalance(holder, 100);
            compliance.created(holder, 100);
        }
        vm.stopPrank();

        assertEq(compliance.holderCount(), MAX_HOLDERS);

        // Transfer to new holder should fail
        bool canTransfer = compliance.canTransfer(user1, user2, 100);
        assertFalse(canTransfer);
    }

    function test_Created_AddsNewHolder() public {
        assertEq(compliance.holderCount(), 0);
        assertFalse(compliance.getIsHolder(user1));

        vm.expectEmit(true, true, true, true);
        emit HolderAdded(user1);

        vm.prank(address(token));
        compliance.created(user1, 100);

        assertEq(compliance.holderCount(), 1);
        assertTrue(compliance.getIsHolder(user1));
    }

    function test_Created_DoesNotAddIfAlreadyHolder() public {
        // Add holder first time
        vm.startPrank(address(token));
        compliance.created(user1, 100);

        assertEq(compliance.holderCount(), 1);

        // Add again should not increase count
        compliance.created(user1, 50);
        vm.stopPrank();

        assertEq(compliance.holderCount(), 1);
    }

    function test_Created_DoesNotAddIfZeroAmount() public {
        vm.prank(address(token));
        compliance.created(user1, 0);

        assertEq(compliance.holderCount(), 0);
        assertFalse(compliance.getIsHolder(user1));
    }

    function test_Transferred_AddsRecipientAsHolder() public {
        token.setBalance(user2, 100);

        vm.expectEmit(true, true, true, true);
        emit HolderAdded(user2);

        vm.prank(address(token));
        compliance.transferred(user1, user2, 100);

        assertTrue(compliance.getIsHolder(user2));
        assertEq(compliance.holderCount(), 1);
    }

    function test_Transferred_RemovesSenderWhenBalanceZero() public {
        // Setup: user1 is a holder
        vm.startPrank(address(token));
        token.setBalance(user1, 100);
        compliance.created(user1, 100);
        vm.stopPrank();

        assertEq(compliance.holderCount(), 1);
        assertTrue(compliance.getIsHolder(user1));

        // Transfer all tokens, balance becomes 0
        token.setBalance(user1, 0);
        token.setBalance(user2, 100);

        vm.expectEmit(true, true, true, true);
        emit HolderRemoved(user1);

        vm.prank(address(token));
        compliance.transferred(user1, user2, 100);

        assertFalse(compliance.getIsHolder(user1));
        assertEq(compliance.holderCount(), 1); // Only user2 now
    }

    function test_Transferred_UpdatesBothHolders() public {
        // Setup: user1 has tokens
        vm.startPrank(address(token));
        token.setBalance(user1, 100);
        compliance.created(user1, 100);
        vm.stopPrank();

        assertEq(compliance.holderCount(), 1);

        // user1 transfers all to user2
        token.setBalance(user1, 0);
        token.setBalance(user2, 100);

        vm.prank(address(token));
        compliance.transferred(user1, user2, 100);

        assertFalse(compliance.getIsHolder(user1));
        assertTrue(compliance.getIsHolder(user2));
        assertEq(compliance.holderCount(), 1);
    }

    function test_Destroyed_RemovesHolderWhenBalanceZero() public {
        // Setup: user1 is a holder
        vm.startPrank(address(token));
        token.setBalance(user1, 100);
        compliance.created(user1, 100);
        vm.stopPrank();

        assertEq(compliance.holderCount(), 1);

        // Burn all tokens
        token.setBalance(user1, 0);

        vm.expectEmit(true, true, true, true);
        emit HolderRemoved(user1);

        vm.prank(address(token));
        compliance.destroyed(user1, 100);

        assertFalse(compliance.getIsHolder(user1));
        assertEq(compliance.holderCount(), 0);
    }

    function test_Destroyed_DoesNotRemoveIfBalanceRemaining() public {
        // Setup: user1 is a holder with 100 tokens
        vm.startPrank(address(token));
        token.setBalance(user1, 100);
        compliance.created(user1, 100);
        vm.stopPrank();

        // Burn 50 tokens, 50 remaining
        token.setBalance(user1, 50);

        vm.prank(address(token));
        compliance.destroyed(user1, 50);

        assertTrue(compliance.getIsHolder(user1));
        assertEq(compliance.holderCount(), 1);
    }

    function test_RevertWhen_TransferredNotCalledByToken() public {
        vm.expectRevert("Only token contract or authorized caller");
        compliance.transferred(user1, user2, 100);
    }

    function test_RevertWhen_CreatedNotCalledByToken() public {
        vm.expectRevert("Only token contract or authorized caller");
        compliance.created(user1, 100);
    }

    function test_RevertWhen_DestroyedNotCalledByToken() public {
        vm.expectRevert("Only token contract or authorized caller");
        compliance.destroyed(user1, 100);
    }

    function testFuzz_MultipleHolders(uint8 numHolders) public {
        numHolders = uint8(bound(numHolders, 1, MAX_HOLDERS));

        vm.startPrank(address(token));
        for (uint256 i = 0; i < numHolders; i++) {
            address holder = address(uint160(i + 1000));
            token.setBalance(holder, 100);
            compliance.created(holder, 100);
        }
        vm.stopPrank();

        assertEq(compliance.holderCount(), numHolders);

        // Can transfer to existing holder
        assertTrue(compliance.canTransfer(user1, address(1000), 50));

        // Cannot transfer to new holder if at max
        if (numHolders == MAX_HOLDERS) {
            assertFalse(compliance.canTransfer(user1, user2, 100));
        } else {
            assertTrue(compliance.canTransfer(user1, user2, 100));
        }
    }
}
