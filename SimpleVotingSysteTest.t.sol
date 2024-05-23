// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SimpleVotingSystem.sol";

contract SimpleVotingSystemTest is Test {
    SimpleVotingSystem public votingSystem;
    address public admin = address(1);
    address public voter1 = address(2);
    address public voter2 = address(3);
    address public founder = address(4);

    function setUp() public {
        votingSystem = new SimpleVotingSystem(admin);
        votingSystem.grantRole(votingSystem.ADMIN_ROLE(), admin);
        votingSystem.grantRole(votingSystem.FOUNDER_ROLE(), founder);
    }

    function testAddCandidate() public {
        vm.prank(admin);
        votingSystem.addCandidate("Candidate 1");
        SimpleVotingSystem.Candidate memory candidate = votingSystem.getCandidate(1);
        assertEq(candidate.id, 1);
        assertEq(candidate.name, "Candidate 1");
        assertEq(candidate.voteCount, 0);
    }

    function testFailAddCandidateWithoutAdminRole() public {
        vm.prank(voter1); // Assurez-vous que ceci est appelé depuis une adresse non-admin
        vm.expectRevert("Caller is not an admin");
        votingSystem.addCandidate("Candidate 2"); // Devrait échouer car msg.sender n'est pas admin
    }

    function testChangeWorkflowStatus() public {
        vm.prank(admin);
        votingSystem.changeWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);
        assertEq(uint(votingSystem.workflowStatus()), uint(SimpleVotingSystem.WorkflowStatus.VOTE));
    }

    function testFailChangeWorkflowStatusWithoutAdminRole() public {
        vm.prank(voter1); // Assurez-vous que ceci est appelé depuis une adresse non-admin
        vm.expectRevert("Caller is not an admin");
        votingSystem.changeWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE); // Devrait échouer car msg.sender n'est pas admin
    }

    function testVote() public {
        vm.prank(admin);
        votingSystem.addCandidate("Candidate 1");

        vm.prank(admin);
        votingSystem.changeWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);

        vm.warp(block.timestamp + 1 hours); // Avance le temps de 1 heure

        vm.prank(voter1);
        votingSystem.vote(1);
        SimpleVotingSystem.Candidate memory candidate = votingSystem.getCandidate(1);
        assertEq(candidate.voteCount, 1);
    }

    function testFailVoteBeforeVotingStart() public {
        vm.prank(admin);
        votingSystem.addCandidate("Candidate 1");

        vm.prank(admin);
        votingSystem.changeWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);

        vm.prank(voter1);
        vm.expectRevert("Voting has not started yet");
        votingSystem.vote(1); // Devrait échouer car le vote n'a pas encore commencé
    }

    function testDesignateWinner() public {
        vm.prank(admin);
        votingSystem.addCandidate("Candidate 1");
        vm.prank(admin);
        votingSystem.addCandidate("Candidate 2");

        vm.prank(admin);
        votingSystem.changeWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);

        vm.warp(block.timestamp + 1 hours); // Avance le temps de 1 heure

        vm.prank(voter1);
        votingSystem.vote(1);
        vm.prank(voter2);
        votingSystem.vote(2);
        vm.prank(founder);
        votingSystem.vote(2);

        vm.prank(admin);
        votingSystem.changeWorkflowStatus(SimpleVotingSystem.WorkflowStatus.COMPLETED);

        SimpleVotingSystem.Candidate memory winner = votingSystem.designateWinner();
        assertEq(winner.id, 2);
        assertEq(winner.voteCount, 2);
    }

    function testReceiveFunds() public {
        vm.prank(admin);
        votingSystem.addCandidate("Candidate 1");

        vm.prank(founder);
        votingSystem.receiveFunds{value: 1 ether}(1);

        // Vérifiez que les fonds ont été reçus par le candidat
        SimpleVotingSystem.Candidate memory candidate = votingSystem.getCandidate(1);
        assertEq(candidate.fundsReceived, 1 ether, "Funds were not received correctly");
    }

    function testFailReceiveFundsWithoutFounderRole() public {
        vm.prank(voter1);
        vm.expectRevert("Caller is not a founder");
        votingSystem.receiveFunds{value: 1 ether}(1); // Devrait échouer car msg.sender n'est pas founder
    }
}
