 // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract VoterContract {
    uint public numberOfCandidates;
    uint public startTime;
    uint256 public stopTime;
    address public admin;

    error AdminOnly();
    error InvalidVotingPeriod();
    error VotingNotOpen();
    error VoterUnderage();
    error VoterAlreadyRegistered();
    error VoterNotRegistered();
    error NotVotersOwnCard();
    error VoterHasVoted();
    error VoterCardExpired();
    error NotValidCandidate();
    error CandidateAlreadyRegistered();
    error InvalidCandidate();

    struct Voter {
        address voterAddress;
        uint8 age;
        uint256 cardExpiry;
        bool hasVoted;
        bool isRegistered;
    }

    struct Candidate {
        address candidate;
        string fullName;
        uint256 votes;
    }

    mapping(address => Voter) public voters;
    mapping(address => Candidate) public candidates;

    event Voted(address indexed voter, address indexed candidate, string candidateName);

    constructor(uint256 _startTime, uint256 _stopTime) {
        if (stopTime > startTime) revert InvalidVotingPeriod();
        startTime = _startTime;
        stopTime = _stopTime;
        admin = msg.sender;
    }

    modifier OnlyAdmin {
        if (msg.sender != admin) revert AdminOnly();
        _;
    }

    modifier duringVoting() {
        if (block.timestamp < startTime || block.timestamp > stopTime) {
            revert VotingNotOpen();
            _;
        }
    }

    function registerVoter(address _voter, uint8 _age) external OnlyAdmin {
        if (_age < 18) revert VoterUnderage();
        if (voters[_voter].isRegistered) revert VoterAlreadyRegistered();

        uint256 _cardExpiry = block.timestamp + 365 days;

        voters[_voter] =  Voter({voterAddress:_voter, age:_age, cardExpiry: _cardExpiry, hasVoted: false, isRegistered: true});

    }

    function addCandidates(address _candidateAddress, string memory _fullName) external OnlyAdmin {
        if (candidates[_candidateAddress].candidate != address(0)) {
            revert CandidateAlreadyRegistered();
        }

        candidates[_candidateAddress] = Candidate({candidate: _candidateAddress, fullName: _fullName, votes: 0});
    }

    function vote(address _candidate) external duringVoting {
        Voter storage voter = voters[msg.sender];
        if (!voter.isRegistered) revert VoterNotRegistered();
        if (voter.voterAddress != msg.sender) revert NotVotersOwnCard();
        if (voter.hasVoted) revert VoterHasVoted();
        if (voter.cardExpiry <= block.timestamp) revert VoterCardExpired();
        if (candidates[_candidate].candidate == address(0)) revert InvalidCandidate();

        voter.hasVoted = true;
        candidates[_candidate].votes++;

        emit Voted(msg.sender, _candidate, candidates[_candidate].fullName);
        
    }

    function getCandidate(address _candidate) external view returns (string memory fullName, uint256 votes) {
        Candidate storage candidate = candidates[_candidate];
        return (candidate.fullName, candidate.votes);
    }

    function getCurrentTime() external view returns (uint256) {
        return block.timestamp;
    }

    function getVoterCardExpiry(address _voter) external view returns (uint256) {
        return voters[_voter].cardExpiry;
    }
}