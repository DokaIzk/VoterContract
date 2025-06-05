// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VoterContract} from "../src/voter.sol";

contract VoterContractTest is Test {
    VoterContract public voterContract;

    address admin = address(0xABCD);
    address voter1 = address(0x1001);
    address voter2 = address(0x1002);
    address candidate1 = address(0x2001);
    address candidate2 = address(0x2002);

    uint256 start;
    uint256 stop;

    function setUp() public {
        start = block.timestamp + 1 days;
        stop = block.timestamp + 3 days;
        vm.prank(admin);
        voterContract = new VoterContract(start, stop);
    }

    function testRegisterVoter() public {
        vm.prank(admin);
        voterContract.registerVoter(voter1, 25);

        (string memory name, uint256 votes) = voterContract.getCandidate(candidate1);
        assertEq(votes, 0); // candidate not yet added
    }

    function testCannotRegisterUnderage() public {
        vm.prank(admin);
        vm.expectRevert(VoterContract.VoterUnderage.selector);
        voterContract.registerVoter(voter1, 16);
    }

    function testAddCandidate() public {
        vm.prank(admin);
        voterContract.addCandidates(candidate1, "Alice");

        (string memory name, uint256 votes) = voterContract.getCandidate(candidate1);
        assertEq(name, "Alice");
        assertEq(votes, 0);
    }

    function testCannotVoteBeforeVotingStart() public {
        vm.prank(admin);
        voterContract.registerVoter(voter1, 30);
        vm.prank(admin);
        voterContract.addCandidates(candidate1, "Alice");

        vm.prank(voter1);
        vm.expectRevert(VoterContract.VotingNotOpen.selector);
        voterContract.vote(candidate1);
    }

    function testSuccessfulVote() public {
        vm.prank(admin);
        voterContract.registerVoter(voter1, 22);
        vm.prank(admin);
        voterContract.addCandidates(candidate1, "Alice");

        vm.warp(start + 1);

        vm.prank(voter1);
        voterContract.vote(candidate1);

        (, uint256 votes) = voterContract.getCandidate(candidate1);
        assertEq(votes, 1);
    }

    function testDoubleVotingFails() public {
        vm.prank(admin);
        voterContract.registerVoter(voter1, 22);
        vm.prank(admin);
        voterContract.addCandidates(candidate1, "Alice");

        vm.warp(start + 1);
        vm.prank(voter1);
        voterContract.vote(candidate1);

        vm.prank(voter1);
        vm.expectRevert(VoterContract.VoterHasVoted.selector);
        voterContract.vote(candidate1);
    }

    function testVotingWithExpiredCardFails() public {
        vm.prank(admin);
        voterContract.registerVoter(voter1, 22);
        vm.prank(admin);
        voterContract.addCandidates(candidate1, "Alice");

        uint256 expiry = voterContract.getVoterCardExpiry(voter1);
        vm.warp(expiry + 1);

        vm.prank(voter1);
        vm.expectRevert(VoterContract.VoterCardExpired.selector);
        voterContract.vote(candidate1);
    }

    function testInvalidCandidateFails() public {
        vm.prank(admin);
        voterContract.registerVoter(voter1, 22);

        vm.warp(start + 1);
        vm.prank(voter1);
        vm.expectRevert(VoterContract.InvalidCandidate.selector);
        voterContract.vote(candidate2);
    }

    function testOnlyAdminCanAddCandidates() public {
        vm.expectRevert(VoterContract.AdminOnly.selector);
        voterContract.addCandidates(candidate1, "Alice");
    }

    function testOnlyAdminCanRegisterVoter() public {
        vm.expectRevert(VoterContract.AdminOnly.selector);
        voterContract.registerVoter(voter1, 22);
    }
}


