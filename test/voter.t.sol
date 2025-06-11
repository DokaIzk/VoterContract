// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VotingContract} from "../src/voter.sol";

contract VoterContractTest is Test {
    VotingContract public voting;
    address public INECChairman;
    address public voter1;
    address public voter2;
    address public candidate1;
    address public candidate2;
    uint256 deployedAt;

    function setUp() public {
        vm.warp(400 days);
        INECChairman = address(this);
        voter1 = address(0x1);
        voter2 = address(0x2);
        candidate1 = address(0x3);
        candidate2 = address(0x4);
        deployedAt = block.timestamp;

        voting = new VotingContract(deployedAt, deployedAt + 1 days);
        voting.setTesting(true);
    }

    function testOnlyChairmanCanRegisterVoters() public {
        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSelector(VotingContract.OnlyINEC.selector, "Only INEC Can Call This Function"));

        voting.registerVoter(voter2, 18, VotingContract.Gender.Male);

        console.log("startTime:", voting.startTime());
        console.log("stopTime:", voting.stopTime());
    }

    function testRegisterUnderageVoter() public {
        vm.expectRevert(abi.encodeWithSelector(VotingContract.VoterUnderage.selector, "Must Be Above 18 Years Of Age"));
        voting.registerVoter(voter2, 12, VotingContract.Gender.Male);
    }

    function testRegisterVoter() public {
        console.log(msg.sender);
        vm.prank(voter1);
        voting.registerVoter(voter1, 19, VotingContract.Gender.Male);
        (,, uint256 voterCard,, bool registered,,) = voting.voters(voter1);
        assertTrue(registered);
        assertGt(voterCard, block.timestamp);
    }

    function testRegisterSameVoterTwice() public {
        voting.registerVoter(voter1, 19, VotingContract.Gender.Male);
        vm.expectRevert(
            abi.encodeWithSelector(VotingContract.VoterAlreadyRegistered.selector, "Voter Has Already Been Registered")
        );
        voting.registerVoter(voter1, 19, VotingContract.Gender.Male);
    }

    function testAddCandidate() public {
        voting.addCandidates(
            candidate1, "Goodluck Ebele Jonathan", VotingContract.Party.PDP, VotingContract.Gender.Male
        );

        (, string memory fullName, VotingContract.Party party, uint256 votes, VotingContract.Gender gender) =
            voting.candidates(candidate1);

        assertEq(fullName, "Goodluck Ebele Jonathan");
        assertEq(votes, 0);
        assertEq(uint8(party), uint8(VotingContract.Party.PDP));
        assertEq(uint8(gender), uint8(VotingContract.Gender.Male));
    }

    function testAddDuplicateCandidate() public {
        voting.addCandidates(
            candidate1, "Goodluck Ebele Jonathan", VotingContract.Party.PDP, VotingContract.Gender.Male
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                VotingContract.CandidateAlreadyRegistered.selector, "This Candidate Has Already Been Registered"
            )
        );
        voting.addCandidates(
            candidate1, "Goodluck Ebele Jonathan", VotingContract.Party.PDP, VotingContract.Gender.Male
        );
    }

    function testCandidateIsValid() public {
        address invalidCandidate = address(0x111);

        voting.addCandidates(
            candidate1, "Goodluck Ebele Jonathan", VotingContract.Party.PDP, VotingContract.Gender.Male
        );
        assertTrue(voting.validCandidate(candidate1));
        assertFalse(voting.validCandidate(invalidCandidate));
    }

    function testVoting() public {
        voting.addCandidates(
            candidate1, "Goodluck Ebele Jonathan", VotingContract.Party.PDP, VotingContract.Gender.Male
        );
        voting.registerVoter(voter1, 30, VotingContract.Gender.Male);

        vm.prank(voter1);
        voting.vote(candidate1);

        (,,, bool hasVoted,,,) = voting.voters(voter1);
        (,,, uint256 votes,) = voting.candidates(candidate1);

        assertTrue(hasVoted);
        assertEq(votes, 1);
    }

    function testUnregisteredVoterVoting() public {
        voting.addCandidates(candidate2, "Patience Jonathan", VotingContract.Party.PDP, VotingContract.Gender.Female);

        vm.prank(voter2);
        vm.expectRevert(
            abi.encodeWithSelector(VotingContract.VoterNotRegistered.selector, "Voter Has Not Been Registered")
        );
        voting.vote(candidate2);
    }

    function testVoterCardExpired() public {
        vm.warp(deployedAt - 366 days);
        voting.registerVoter(voter2, 29, VotingContract.Gender.Female);

        vm.warp(deployedAt + 1 hours);

        voting.addCandidates(candidate2, "Patience Jonathan", VotingContract.Party.PDP, VotingContract.Gender.Female);

        vm.prank(voter2);
        vm.expectRevert(abi.encodeWithSelector(VotingContract.VoterCardExpired.selector, "Voter's Card Has Expired"));
        voting.vote(candidate2);
    }

    function testVoterVotingTwice() public {
        voting.addCandidates(
            candidate1, "Goodluck Ebele Jonathan", VotingContract.Party.PDP, VotingContract.Gender.Male
        );
        voting.registerVoter(voter1, 30, VotingContract.Gender.Male);

        vm.prank(voter1);
        voting.vote(candidate1);

        vm.prank(voter1);
        vm.expectRevert(abi.encodeWithSelector(VotingContract.VoterHasVoted.selector, "Voter Has Already Voted"));
        voting.vote(candidate1);
    }

    function testGetResultsAndWinners() public {
        voting.addCandidates(
            candidate1, "Goodluck Ebele Jonathan", VotingContract.Party.PDP, VotingContract.Gender.Male
        );
        voting.addCandidates(candidate2, "Muhammadu Buhari", VotingContract.Party.APC, VotingContract.Gender.Male);

        voting.registerVoter(voter1, 19, VotingContract.Gender.Male);
        voting.registerVoter(voter2, 18, VotingContract.Gender.Male);

        vm.prank(voter1);
        voting.vote(candidate1);

        vm.prank(voter2);
        voting.vote(candidate2);

        VotingContract.Candidate[] memory results = voting.getResults();
        // assertEq(results.length, 2);
        assertEq(results[0].votes + results[1].votes, 2);

        VotingContract.Candidate[] memory winners = voting.getWinners();
        assertEq(winners.length, 2);
    }
}
