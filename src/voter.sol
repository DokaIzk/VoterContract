    // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract VotingContract {
    uint256 public totalVoters;
    uint256 public startTime;
    uint256 public stopTime;
    address public INECChairman;
    bool public isTesting;

    error OnlyINEC(string reason);
    error InvalidVotingPeriod(string reason);
    error VotingNotOpen(string reason);
    error VoterUnderage(string reason);
    error VoterAlreadyRegistered(string reason);
    error VoterNotRegistered(string reason);
    error NotVotersOwnCard(string reason);
    error VoterHasVoted(string reason);
    error VoterCardExpired(string reason);
    error NotValidCandidate(string reason);
    error CandidateAlreadyRegistered(string reason);
    error InvalidCandidate(string reason);
    error ContractsNotAllowed(string reason);
    error RescheduledStartTime(string reason);
    error RescheduledStopTime(string reason);

    enum Gender {
        Male,
        Female
    }

    enum Party {
        APC,
        PDP,
        LP,
        NNPP,
        ADC
    }

    struct Voter {
        address voterAddress;
        uint8 age;
        uint256 voterCard;
        bool hasVoted;
        bool registered;
        Gender gender;
        uint256 registeredAt;
    }

    struct Candidate {
        address candidate;
        string fullName;
        Party party;
        uint256 votes;
        Gender gender;
    }

    struct VotersGender {
        uint256 males;
        uint256 females;
    }

    address[] public votersList;
    address[] public candidateList;

    mapping(address => Voter) public voters;
    mapping(address => Candidate) public candidates;

    event CandidateAdded(address indexed candidate, string fullName);
    event VoterRegistered(address indexed voter);
    event Voted(address indexed voter);
    event VotingHasStarted();
    event VotingHasEnded();
    event ElectionRescheduled(uint256 startTime, uint256 stopTime);

    constructor(uint256 _startTime, uint256 _stopTime) {
        startTime = _startTime;
        stopTime = _stopTime;
        INECChairman = msg.sender;
    }

    function setTesting(bool _testing) external {
        isTesting = _testing;
    }

    modifier INEC() {
        if (msg.sender != INECChairman) revert OnlyINEC("Only INEC Can Call This Function");
        _;
    }

    modifier OnlyEOAs() {
        if (!isTesting && msg.sender != tx.origin) revert ContractsNotAllowed("Contracts Can Not Call This Function");
        _;
    }

    function registerVoter(address _voter, uint8 _age, Gender _gender) external INEC {
        if (_age < 18) revert VoterUnderage("Must Be Above 18 Years Of Age");
        if (voters[_voter].registered) revert VoterAlreadyRegistered("Voter Has Already Been Registered");

        uint256 _voterCard = block.timestamp + 365 days;

        voters[_voter] = Voter({
            voterAddress: _voter,
            age: _age,
            voterCard: _voterCard,
            hasVoted: false,
            registered: true,
            gender: _gender,
            registeredAt: block.timestamp
        });

        votersList.push(_voter);

        totalVoters++;

        emit VoterRegistered(_voter);
    }

    function addCandidates(address _candidateAddress, string memory _fullName, Party _party, Gender _gender)
        external
        INEC
    {
        if (candidates[_candidateAddress].candidate != address(0)) {
            revert CandidateAlreadyRegistered("This Candidate Has Already Been Registered");
        }

        candidates[_candidateAddress] =
            Candidate({candidate: _candidateAddress, fullName: _fullName, party: _party, votes: 0, gender: _gender});

        candidateList.push(_candidateAddress);

        emit CandidateAdded(_candidateAddress, _fullName);
    }

    function vote(address _candidate) external OnlyEOAs {
        if (stopTime <= startTime) revert InvalidVotingPeriod("The Stop Time Must Be Set After Start Time");
        if (block.timestamp < startTime || block.timestamp > stopTime) {
            revert VotingNotOpen("Voting Is Not Currently Active");
        }

        Voter storage voter = voters[msg.sender];
        if (!voter.registered) revert VoterNotRegistered("Voter Has Not Been Registered");
        if (voter.voterAddress != msg.sender) revert NotVotersOwnCard("Voter Using A Different Voter's Card");
        if (voter.hasVoted) revert VoterHasVoted("Voter Has Already Voted");
        if (voter.voterCard <= block.timestamp) revert VoterCardExpired("Voter's Card Has Expired");
        if (!validCandidate(_candidate)) revert InvalidCandidate("Candidate Is Not Registered");
        // if (candidates[_candidate].candidate == address(0)) revert InvalidCandidate("Candidate Is Not Registered");

        voter.hasVoted = true;
        candidates[_candidate].votes++;

        emit Voted(msg.sender);
    }

    function rescheduleElection(uint256 _startTime, uint256 _stopTime) external INEC {
        if (_startTime <= block.timestamp) {
            revert RescheduledStartTime("Rescheduled Start Time Must Be Later In The Future");
        }
        if (_stopTime <= _startTime) revert RescheduledStopTime("Rescheduled Stop Time Must Be After Start Time");
        startTime = _startTime;
        stopTime = _stopTime;

        emit ElectionRescheduled(_startTime, _stopTime);
    }

    function validCandidate(address _candidate) public view returns (bool) {
        for (uint256 i = 0; i < candidateList.length; i++) {
            if (candidateList[i] == _candidate) return true;
        }
        return false;
    }

    function getCandidate(address _candidate) external view returns (string memory fullName, uint256 votes) {
        Candidate storage candidate = candidates[_candidate];
        return (candidate.fullName, candidate.votes);
    }

    function getCurrentTime() external view returns (uint256) {
        return block.timestamp;
    }

    function getVoterCardExpiry(address _voter) external view returns (uint256) {
        return voters[_voter].voterCard;
    }

    function getTotalRegisteredVoters() external view returns (uint256) {
        return totalVoters;
    }

    function getGenderCountOfVoters() external view returns (VotersGender memory result) {
        for (uint256 i = 0; i < votersList.length; i++) {
            Gender gender = voters[votersList[i]].gender;

            if (gender == Gender.Male) result.males++;
            else if (gender == Gender.Female) result.females++;
        }
    }

    function getResults() external view returns (Candidate[] memory) {
        Candidate[] memory results = new Candidate[](candidateList.length);

        for (uint256 i = 0; i < candidateList.length; i++) {
            address candidate = candidateList[i];
            results[i] = candidates[candidate];
        }
        return results;
    }

    // If two candidates both have the highests number of votes, both candidates will be returned
    function getWinners() external view returns (Candidate[] memory) {
        Candidate[] memory temp = new Candidate[](candidateList.length);
        uint256 highestVotes;
        uint256 winnerCount;

        // Loop to get the highest vote count
        for (uint256 i = 0; i < candidateList.length; i++) {
            uint256 votes = candidates[candidateList[i]].votes;

            if (votes > highestVotes) {
                highestVotes = votes;
                winnerCount = 1;
                temp[0] = candidates[candidateList[i]];
            } else if (votes == highestVotes) {
                temp[winnerCount] = candidates[candidateList[i]];
                winnerCount++;
            }
        }

        // Get Winner(s)
        Candidate[] memory winners = new Candidate[](winnerCount);
        for (uint256 i = 0; i < winnerCount; i++) {
            winners[i] = temp[i];
        }
        return winners;
    }
}
