// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TransferLockCompliance} from "../src/compliance/TransferLockCompliance.sol";

contract TransferLockComplianceTest is Test {
    TransferLockCompliance public compliance;

    address public owner;
    address public tokenContract;
    address public user1;
    address public user2;

    uint256 constant LOCK_PERIOD = 30 days;

    event LockPeriodSet(uint256 lockPeriod);
    event TransferLocked(address indexed account, uint256 lockEndTime);

    function setUp() public {
        owner = address(this);
        tokenContract = makeAddr("token");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy compliance module
        compliance = new TransferLockCompliance(owner, LOCK_PERIOD);

        // Set token contract
        compliance.setTokenContract(tokenContract);
    }

    function test_Constructor() public {
        assertEq(compliance.lockPeriod(), LOCK_PERIOD);
        assertEq(compliance.owner(), owner);
        assertEq(compliance.tokenContract(), tokenContract);
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
        compliance.setTokenContract(tokenContract);
    }

    function test_SetLockPeriod() public {
        uint256 newLockPeriod = 60 days;

        vm.expectEmit(true, true, true, true);
        emit LockPeriodSet(newLockPeriod);

        compliance.setLockPeriod(newLockPeriod);
        assertEq(compliance.lockPeriod(), newLockPeriod);
    }

    function test_RevertWhen_SetLockPeriodNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        compliance.setLockPeriod(60 days);
    }

    function test_CanTransfer_WhenNotLocked() public {
        // User1 has no lock
        bool canTransfer = compliance.canTransfer(user1, user2, 100);
        assertTrue(canTransfer);
    }

    function test_CanTransfer_FailsWhenLocked() public {
        // Lock user1
        vm.prank(tokenContract);
        compliance.created(user1, 100);

        // user1 should be locked
        assertTrue(compliance.isLocked(user1));

        // Cannot transfer while locked
        bool canTransfer = compliance.canTransfer(user1, user2, 50);
        assertFalse(canTransfer);
    }

    function test_CanTransfer_SucceedsAfterLockExpiry() public {
        // Lock user1
        vm.prank(tokenContract);
        compliance.created(user1, 100);

        assertTrue(compliance.isLocked(user1));

        // Fast forward past lock period
        vm.warp(block.timestamp + LOCK_PERIOD + 1);

        assertFalse(compliance.isLocked(user1));

        // Should be able to transfer now
        bool canTransfer = compliance.canTransfer(user1, user2, 50);
        assertTrue(canTransfer);
    }

    function test_Created_SetsLockPeriod() public {
        uint256 expectedLockEnd = block.timestamp + LOCK_PERIOD;

        vm.expectEmit(true, true, true, true);
        emit TransferLocked(user1, expectedLockEnd);

        vm.prank(tokenContract);
        compliance.created(user1, 100);

        assertEq(compliance.getLockEndTime(user1), expectedLockEnd);
        assertTrue(compliance.isLocked(user1));
    }

    function test_Transferred_SetsLockOnRecipient() public {
        uint256 expectedLockEnd = block.timestamp + LOCK_PERIOD;

        vm.expectEmit(true, true, true, true);
        emit TransferLocked(user2, expectedLockEnd);

        vm.prank(tokenContract);
        compliance.transferred(user1, user2, 100);

        assertEq(compliance.getLockEndTime(user2), expectedLockEnd);
        assertTrue(compliance.isLocked(user2));
    }

    function test_Transferred_UpdatesExistingLock() public {
        // Lock user2 initially
        vm.prank(tokenContract);
        compliance.created(user2, 100);

        uint256 initialLockEnd = compliance.getLockEndTime(user2);

        // Move time forward
        vm.warp(block.timestamp + 10 days);

        // Transfer to user2 again
        vm.prank(tokenContract);
        compliance.transferred(user1, user2, 50);

        uint256 newLockEnd = compliance.getLockEndTime(user2);

        // New lock should be set from current timestamp
        assertGt(newLockEnd, initialLockEnd);
        assertEq(newLockEnd, block.timestamp + LOCK_PERIOD);
    }

    function test_Destroyed_DoesNothing() public {
        // destroyed() should not revert (no-op function)
        vm.prank(tokenContract);
        compliance.destroyed(user1, 100);
    }

    function test_GetLockEndTime() public {
        assertEq(compliance.getLockEndTime(user1), 0);

        vm.prank(tokenContract);
        compliance.created(user1, 100);

        assertEq(compliance.getLockEndTime(user1), block.timestamp + LOCK_PERIOD);
    }

    function test_IsLocked() public {
        assertFalse(compliance.isLocked(user1));

        vm.prank(tokenContract);
        compliance.created(user1, 100);

        assertTrue(compliance.isLocked(user1));

        // Fast forward past lock
        vm.warp(block.timestamp + LOCK_PERIOD);

        assertFalse(compliance.isLocked(user1));
    }

    function test_GetRemainingLockTime() public {
        assertEq(compliance.getRemainingLockTime(user1), 0);

        vm.prank(tokenContract);
        compliance.created(user1, 100);

        // Should have full lock period remaining
        assertEq(compliance.getRemainingLockTime(user1), LOCK_PERIOD);

        // Move forward 10 days
        vm.warp(block.timestamp + 10 days);

        // Should have 20 days remaining
        assertEq(compliance.getRemainingLockTime(user1), LOCK_PERIOD - 10 days);

        // Move past lock period
        vm.warp(block.timestamp + LOCK_PERIOD);

        // Should have 0 remaining
        assertEq(compliance.getRemainingLockTime(user1), 0);
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

    function testFuzz_LockPeriod(uint256 lockDuration) public {
        // Bound to reasonable values (1 second to 10 years)
        lockDuration = bound(lockDuration, 1, 365 days * 10);

        TransferLockCompliance newCompliance = new TransferLockCompliance(owner, lockDuration);
        newCompliance.setTokenContract(tokenContract);

        assertEq(newCompliance.lockPeriod(), lockDuration);

        uint256 expectedLockEnd = block.timestamp + lockDuration;

        vm.prank(tokenContract);
        newCompliance.created(user1, 100);

        assertEq(newCompliance.getLockEndTime(user1), expectedLockEnd);
        assertTrue(newCompliance.isLocked(user1));

        // Fast forward to just before lock expires
        vm.warp(block.timestamp + lockDuration - 1);
        assertTrue(newCompliance.isLocked(user1));

        // Fast forward to exact expiry
        vm.warp(block.timestamp + 1);
        assertFalse(newCompliance.isLocked(user1));
    }

    function testFuzz_MultipleLocksAndUnlocks(uint8 numUsers) public {
        numUsers = uint8(bound(numUsers, 1, 50));

        vm.startPrank(tokenContract);

        for (uint256 i = 0; i < numUsers; i++) {
            address user = address(uint160(i + 1000));
            compliance.created(user, 100);

            assertTrue(compliance.isLocked(user));
            assertEq(compliance.getLockEndTime(user), block.timestamp + LOCK_PERIOD);
        }

        vm.stopPrank();

        // Fast forward past lock period
        vm.warp(block.timestamp + LOCK_PERIOD + 1);

        for (uint256 i = 0; i < numUsers; i++) {
            address user = address(uint160(i + 1000));
            assertFalse(compliance.isLocked(user));
            assertEq(compliance.getRemainingLockTime(user), 0);
        }
    }

    function test_CanTransferAtExactLockExpiry() public {
        vm.prank(tokenContract);
        compliance.created(user1, 100);

        uint256 lockEnd = compliance.getLockEndTime(user1);

        // Just before lock expiry
        vm.warp(lockEnd - 1);
        assertFalse(compliance.canTransfer(user1, user2, 50));

        // At exact lock expiry
        vm.warp(lockEnd);
        assertTrue(compliance.canTransfer(user1, user2, 50));
    }
}
