// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {GovernanceMultisig} from "../src/GovernanceMultisig.sol";

contract MockGovernanceTarget {
    uint256 public value;

    function setValue(uint256 newValue) external {
        value = newValue;
    }

    function fail() external pure {
        revert("boom");
    }

    receive() external payable {}
}

/**
 * @title GovernanceMultisigTest
 * @notice H-06 (R-7 / D-021): gobernanza 2-de-3 con timelock.
 */
contract GovernanceMultisigTest is Test {
    GovernanceMultisig internal multisig;
    MockGovernanceTarget internal target;

    address internal o1 = makeAddr("owner1");
    address internal o2 = makeAddr("owner2");
    address internal o3 = makeAddr("owner3");
    address internal stranger = makeAddr("stranger");

    uint256 internal constant DELAY = 2 days;

    address[] internal owners;

    event ProposalCreated(
        uint256 indexed id, address indexed proposer, address indexed target, uint256 value, bytes data, uint256 readyAt
    );

    function setUp() public {
        owners = [o1, o2, o3];
        multisig = new GovernanceMultisig(owners, 2, DELAY);
        target = new MockGovernanceTarget();
    }

    // ================= Constructor =================

    function test_Constructor_ConfiguraOwnersUmbralYDelay() public view {
        assertEq(multisig.ownerCount(), 3);
        assertEq(multisig.threshold(), 2);
        assertEq(multisig.delay(), DELAY);
        assertTrue(multisig.isOwner(o1));
        assertFalse(multisig.isOwner(stranger));
        assertEq(multisig.getOwners()[0], o1);
    }

    function test_Constructor_RevertWhen_SinOwners() public {
        address[] memory empty = new address[](0);
        vm.expectRevert("Owners required");
        new GovernanceMultisig(empty, 1, DELAY);
    }

    function test_Constructor_RevertWhen_DemasiadosOwners() public {
        address[] memory many = new address[](11);
        for (uint256 i = 0; i < 11; i++) {
            many[i] = address(uint160(100 + i));
        }
        vm.expectRevert("Too many owners");
        new GovernanceMultisig(many, 1, DELAY);
    }

    function test_Constructor_RevertWhen_UmbralInvalido() public {
        vm.expectRevert("Invalid threshold");
        new GovernanceMultisig(owners, 0, DELAY);

        vm.expectRevert("Invalid threshold");
        new GovernanceMultisig(owners, 4, DELAY);
    }

    function test_Constructor_RevertWhen_OwnerCero() public {
        address[] memory withZero = new address[](2);
        withZero[0] = o1;
        withZero[1] = address(0);
        vm.expectRevert("Invalid owner");
        new GovernanceMultisig(withZero, 1, DELAY);
    }

    function test_Constructor_RevertWhen_OwnerDuplicado() public {
        address[] memory dup = new address[](2);
        dup[0] = o1;
        dup[1] = o1;
        vm.expectRevert("Duplicate owner");
        new GovernanceMultisig(dup, 1, DELAY);
    }

    // ================= propose / approve =================

    function test_Propose_OnlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert("Not an owner");
        multisig.propose(address(target), 0, abi.encodeCall(MockGovernanceTarget.setValue, (1)));
    }

    function test_Propose_RevertWhen_TargetCero() public {
        vm.prank(o1);
        vm.expectRevert("Invalid target");
        multisig.propose(address(0), 0, "");
    }

    function test_Propose_EmiteEventoYGuardaReadyAt() public {
        bytes memory data = abi.encodeCall(MockGovernanceTarget.setValue, (42));
        vm.expectEmit(true, true, true, true);
        emit ProposalCreated(1, o1, address(target), 0, data, block.timestamp + DELAY);

        vm.prank(o1);
        uint256 id = multisig.propose(address(target), 0, data);

        assertEq(id, 1);
        assertEq(multisig.proposalCount(), 1);
        (address t, uint256 v, bytes memory d, uint256 readyAt, uint256 approvals, bool executed, bool cancelled) =
            multisig.getProposal(id);
        assertEq(t, address(target));
        assertEq(v, 0);
        assertEq(d, data);
        assertEq(readyAt, block.timestamp + DELAY);
        assertEq(approvals, 0);
        assertFalse(executed);
        assertFalse(cancelled);
    }

    function test_Approve_OnlyOwnerYNoDuplicado() public {
        vm.prank(o1);
        uint256 id = multisig.propose(address(target), 0, "");

        vm.prank(stranger);
        vm.expectRevert("Not an owner");
        multisig.approve(id);

        vm.prank(o1);
        multisig.approve(id);
        (,,,, uint256 approvals,,) = multisig.getProposal(id);
        assertEq(approvals, 1);
        assertTrue(multisig.hasApproved(id, o1));

        // Doble aprobación del mismo owner revierte.
        vm.prank(o1);
        vm.expectRevert("Already approved");
        multisig.approve(id);
    }

    function test_Approve_RevertWhen_PropuestaNoExiste() public {
        vm.prank(o1);
        vm.expectRevert("Proposal does not exist");
        multisig.approve(99);
    }

    // ================= execute =================

    function test_Execute_FlujoCompleto_DosDeTresConTimelock() public {
        bytes memory data = abi.encodeCall(MockGovernanceTarget.setValue, (7));
        vm.prank(o1);
        uint256 id = multisig.propose(address(target), 0, data);

        vm.prank(o1);
        multisig.approve(id);
        assertTrue(multisig.hasApproved(id, o1));
        (,,,, uint256 approvalsCount,,) = multisig.getProposal(id);
        assertEq(approvalsCount, 1);

        // Con 1 aprobación no basta.
        vm.prank(o2);
        vm.expectRevert("Not enough approvals");
        multisig.execute(id);

        vm.prank(o2);
        multisig.approve(id);
        (,,,, uint256 approvals2,,) = multisig.getProposal(id);
        assertEq(approvals2, 2);

        // Timelock no vencido.
        vm.prank(o3);
        vm.expectRevert("Timelock not expired");
        multisig.execute(id);

        vm.warp(block.timestamp + DELAY);
        vm.prank(o3);
        multisig.execute(id);

        assertEq(target.value(), 7);
        (,,,,, bool executed,) = multisig.getProposal(id);
        assertTrue(executed);
    }

    function test_Execute_RevertWhen_CallFalla() public {
        vm.prank(o1);
        uint256 id = multisig.propose(address(target), 0, abi.encodeCall(MockGovernanceTarget.fail, ()));
        vm.prank(o1);
        multisig.approve(id);
        vm.prank(o2);
        multisig.approve(id);
        vm.warp(block.timestamp + DELAY);

        vm.prank(o1);
        vm.expectRevert(bytes("boom"));
        multisig.execute(id);
    }

    function test_Execute_RevertWhen_YaEjecutada() public {
        vm.prank(o1);
        uint256 id = multisig.propose(address(target), 0, abi.encodeCall(MockGovernanceTarget.setValue, (1)));
        vm.prank(o1);
        multisig.approve(id);
        vm.prank(o2);
        multisig.approve(id);
        vm.warp(block.timestamp + DELAY);
        vm.prank(o1);
        multisig.execute(id);

        vm.prank(o1);
        vm.expectRevert("Proposal closed");
        multisig.execute(id);
    }

    function test_Execute_ConValor() public {
        vm.deal(address(multisig), 1 ether);
        vm.prank(o1);
        uint256 id = multisig.propose(address(target), 1 ether, "");
        vm.prank(o1);
        multisig.approve(id);
        vm.prank(o2);
        multisig.approve(id);
        vm.warp(block.timestamp + DELAY);
        vm.prank(o1);
        multisig.execute(id);

        assertEq(address(target).balance, 1 ether);
    }

    // ================= cancel =================

    function test_Cancel_ImpideEjecucion() public {
        vm.prank(o1);
        uint256 id = multisig.propose(address(target), 0, abi.encodeCall(MockGovernanceTarget.setValue, (9)));
        vm.prank(o2);
        multisig.cancel(id);
        (,,,,,, bool cancelled) = multisig.getProposal(id);
        assertTrue(cancelled);

        vm.prank(o1);
        vm.expectRevert("Proposal closed");
        multisig.approve(id);

        vm.warp(block.timestamp + DELAY);
        vm.prank(o1);
        vm.expectRevert("Proposal closed");
        multisig.execute(id);
        assertEq(target.value(), 0);
    }

    function test_Cancel_RevertWhen_NoOwnerONoExiste() public {
        vm.prank(o1);
        uint256 id = multisig.propose(address(target), 0, "");
        vm.prank(stranger);
        vm.expectRevert("Not an owner");
        multisig.cancel(id);

        vm.prank(o1);
        vm.expectRevert("Proposal does not exist");
        multisig.cancel(123);
    }

    // ================= mantenimiento vía gobernanza =================

    function _enact(address targetAddr, bytes memory data) internal returns (uint256 id) {
        vm.prank(o1);
        id = multisig.propose(targetAddr, 0, data);
        vm.prank(o1);
        multisig.approve(id);
        vm.prank(o2);
        multisig.approve(id);
        vm.warp(block.timestamp + DELAY);
        vm.prank(o2);
        multisig.execute(id);
    }

    function test_Gobernanza_AddOwner() public {
        address newOwner = makeAddr("owner4");
        _enact(address(multisig), abi.encodeCall(GovernanceMultisig.addOwner, (newOwner)));
        assertTrue(multisig.isOwner(newOwner));
        assertEq(multisig.ownerCount(), 4);
    }

    function test_Gobernanza_AddRemoveOwner() public {
        // Añadir un owner (umbral sigue en 2) y luego quitarlo; el umbral no puede exceder owners.
        address newOwner = makeAddr("owner4");
        _enact(address(multisig), abi.encodeCall(GovernanceMultisig.addOwner, (newOwner)));
        assertEq(multisig.ownerCount(), 4);

        _enact(address(multisig), abi.encodeCall(GovernanceMultisig.removeOwner, (o3)));
        assertFalse(multisig.isOwner(o3));
        assertEq(multisig.ownerCount(), 3);
    }

    function test_Gobernanza_SetThresholdYDelay() public {
        _enact(address(multisig), abi.encodeCall(GovernanceMultisig.setThreshold, (3)));
        assertEq(multisig.threshold(), 3);

        // Con umbral 3 hacen falta tres aprobaciones; el retardo vigente sigue siendo DELAY hasta
        // que la propuesta de `setDelay` se ejecuta.
        vm.prank(o1);
        uint256 id = multisig.propose(address(multisig), 0, abi.encodeCall(GovernanceMultisig.setDelay, (3 days)));
        vm.prank(o1);
        multisig.approve(id);
        vm.prank(o2);
        multisig.approve(id);
        vm.prank(o3);
        multisig.approve(id);
        vm.warp(block.timestamp + DELAY);
        vm.prank(o1);
        multisig.execute(id);
        assertEq(multisig.delay(), 3 days);
    }

    function test_Gobernanza_RevertWhen_LlamadaDirecta() public {
        vm.prank(o1);
        vm.expectRevert("Only via governance");
        multisig.addOwner(makeAddr("x"));

        vm.prank(o1);
        vm.expectRevert("Only via governance");
        multisig.setThreshold(1);
    }

    function test_Gobernanza_RemoveOwner_RevertWhen_UmbralExcede() public {
        // 3 owners, umbral 3: quitar un owner dejaría 2 < 3.
        _enact(address(multisig), abi.encodeCall(GovernanceMultisig.setThreshold, (3)));
        vm.prank(o1);
        uint256 id = multisig.propose(address(multisig), 0, abi.encodeCall(GovernanceMultisig.removeOwner, (o3)));
        vm.prank(o1);
        multisig.approve(id);
        vm.prank(o2);
        multisig.approve(id);
        vm.prank(o3);
        multisig.approve(id);
        vm.warp(block.timestamp + DELAY);
        vm.prank(o2);
        vm.expectRevert("Threshold exceeds owners");
        multisig.execute(id);
    }

    function test_Receive_RecibeFondos() public {
        vm.deal(o1, 1 ether);
        vm.prank(o1);
        (bool ok,) = address(multisig).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(multisig).balance, 1 ether);
    }
}
