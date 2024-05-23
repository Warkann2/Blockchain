// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract SimpleVotingSystem is AccessControl {
    struct Candidate {
        uint id;
        string name;
        uint voteCount;
        uint fundsReceived;
    }

    enum WorkflowStatus { REGISTER_CANDIDATES, FOUND_CANDIDATES, VOTE, COMPLETED }
    WorkflowStatus public workflowStatus;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");

    mapping(uint => Candidate) public candidates;
    mapping(address => bool) public voters;
    uint[] private candidateIds;
    uint public voteStartTime;

    event CandidateAdded(uint indexed candidateId, string name);
    event Voted(address indexed voter, uint indexed candidateId);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event FundsReceived(address indexed founder, uint amount, uint candidateId);
    
    constructor(address _admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(FOUNDER_ROLE, _admin);
        workflowStatus = WorkflowStatus.REGISTER_CANDIDATES;
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    modifier onlyFounder() {
        require(hasRole(FOUNDER_ROLE, msg.sender), "Caller is not a founder");
        _;
    }

    modifier inWorkflowStatus(WorkflowStatus _status) {
        require(workflowStatus == _status, "Invalid workflow status for this action");
        _;
    }

    function addCandidate(string memory _name) public onlyAdmin inWorkflowStatus(WorkflowStatus.REGISTER_CANDIDATES) {
        require(bytes(_name).length > 0, "Candidate name cannot be empty");
        uint candidateId = candidateIds.length + 1;
        candidates[candidateId] = Candidate(candidateId, _name, 0, 0);
        candidateIds.push(candidateId);
        emit CandidateAdded(candidateId, _name);
    }

    function vote(uint _candidateId) public inWorkflowStatus(WorkflowStatus.VOTE) {
        require(!voters[msg.sender], "You have already voted");
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
        require(block.timestamp >= voteStartTime + 1 hours, "Voting has not started yet");

        voters[msg.sender] = true;
        candidates[_candidateId].voteCount += 1;
        emit Voted(msg.sender, _candidateId);
    }

    function changeWorkflowStatus(WorkflowStatus _newStatus) public onlyAdmin {
        emit WorkflowStatusChange(workflowStatus, _newStatus);
        workflowStatus = _newStatus;
        if (_newStatus == WorkflowStatus.VOTE) {
            voteStartTime = block.timestamp;
        }
    }

    function getTotalVotes(uint _candidateId) public view returns (uint) {
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
        return candidates[_candidateId].voteCount;
    }

    function getCandidatesCount() public view returns (uint) {
        return candidateIds.length;
    }

    function getCandidate(uint _candidateId) public view returns (Candidate memory) {
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
        return candidates[_candidateId];
    }

    function designateWinner() public view inWorkflowStatus(WorkflowStatus.COMPLETED) returns (Candidate memory) {
        uint highestVotes = 0;
        Candidate memory winner;
        for (uint i = 1; i <= candidateIds.length; i++) {
            if (candidates[i].voteCount > highestVotes) {
                highestVotes = candidates[i].voteCount;
                winner = candidates[i];
            }
        }
        return winner;
    }

    function receiveFunds(uint _candidateId) public payable onlyFounder {
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
        candidates[_candidateId].fundsReceived += msg.value;
        emit FundsReceived(msg.sender, msg.value, _candidateId);
    }
}
