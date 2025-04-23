// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.20;

import {TurnkeyGovernor} from "../src/TurnkeyGovernor.sol";
import {BaseTest} from "./utils/BaseTest.t.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {IGovernor} from "openzeppelin-contracts/contracts/governance/IGovernor.sol";
import {GovernorPreventLateQuorum} from
    "openzeppelin-contracts/contracts/governance/extensions/GovernorPreventLateQuorum.sol";
import {console} from "forge-std/console.sol";
import {GovernorSettings} from "openzeppelin-contracts/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorVotesQuorumFraction} from
    "openzeppelin-contracts/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

contract TurnkeyGovernorTest is BaseTest {
    function setUp() public override {
        super.setUp();
        turnkeyGovernor = new TurnkeyGovernor(
            "Governor",
            turnkeyERC20,
            defaultQuorumPercentage,
            defaultVoteExtension,
            defaultVotingDelay,
            defaultVotingPeriod,
            defaultProposalThreshold
        );
    }

    function test_constructor() public {
        turnkeyGovernor = new TurnkeyGovernor(
            "Governor",
            turnkeyERC20,
            defaultQuorumPercentage,
            defaultVoteExtension,
            defaultVotingDelay,
            defaultVotingPeriod,
            defaultProposalThreshold
        );

        assertEq(turnkeyGovernor.name(), "Governor", "Name should be Governor");
        assertEq(address(turnkeyGovernor.token()), address(turnkeyERC20), "Token should be turnkeyERC20");
        assertEq(
            turnkeyGovernor.quorumNumerator(),
            defaultQuorumPercentage,
            "Quorum percentage should be defaultQuorumPercentage"
        );
        assertEq(
            turnkeyGovernor.lateQuorumVoteExtension(),
            defaultVoteExtension,
            "Vote extension should be defaultVoteExtension"
        );
        assertEq(turnkeyGovernor.votingDelay(), defaultVotingDelay, "Voting delay should be defaultVotingDelay");
        assertEq(turnkeyGovernor.votingPeriod(), defaultVotingPeriod, "Voting period should be defaultVotingPeriod");
        assertEq(
            turnkeyGovernor.proposalThreshold(),
            defaultProposalThreshold,
            "Proposal threshold should be defaultProposalThreshold"
        );
    }

    function test_propose_success() public {
        ProposalAnnouncement proposalAnnouncement = new ProposalAnnouncement();

        mintAndDelegate(alice, alice, defaultProposalThreshold);
        vm.roll(block.number + 1);

        address[] memory targets = new address[](1);
        targets[0] = address(proposalAnnouncement);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";

        string memory description = "test";
        vm.warp(block.timestamp + 1); // make delegated votes active
        uint256 proposalId = turnkeyGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        vm.startPrank(alice);
        vm.expectEmit(address(turnkeyGovernor));
        emit IGovernor.ProposalCreated(
            proposalId,
            alice,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            block.timestamp + turnkeyGovernor.votingDelay(),
            block.timestamp + turnkeyGovernor.votingPeriod() + turnkeyGovernor.votingDelay(),
            description
        );
        turnkeyGovernor.propose(targets, values, calldatas, description);
    }

    function test_propose_vote_passed_success() public {
        ProposalAnnouncement proposalAnnouncement = new ProposalAnnouncement();

        mintAndDelegate(alice, alice, defaultProposalThreshold);
        mintAndDelegate(bob, alice, defaultProposalThreshold);
        mintAndDelegate(charlie, alice, defaultProposalThreshold);

        address[] memory targets = new address[](1);
        targets[0] = address(proposalAnnouncement);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(ProposalAnnouncement.announceProposal.selector);

        string memory description = "test";
        vm.warp(block.timestamp + 1); // make delegated votes active
        uint256 proposalId = turnkeyGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        vm.startPrank(alice);
        vm.expectEmit(address(turnkeyGovernor));
        emit IGovernor.ProposalCreated(
            proposalId,
            alice,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            block.timestamp + turnkeyGovernor.votingDelay(),
            block.timestamp + turnkeyGovernor.votingPeriod() + turnkeyGovernor.votingDelay(),
            description
        );
        turnkeyGovernor.propose(targets, values, calldatas, description);
        vm.stopPrank();

        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Pending), "proposal not pending"
        );
        vm.warp(block.timestamp + turnkeyGovernor.votingDelay() + 1);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), false, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), false, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), false, "charlie has voted");
        assertEq(uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Active), "proposal not active");

        vm.prank(alice);
        turnkeyGovernor.castVote(proposalId, 1);

        vm.prank(bob);
        turnkeyGovernor.castVote(proposalId, 0);

        vm.prank(charlie);
        turnkeyGovernor.castVote(proposalId, 1);

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod());
        vm.prank(alice);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), true, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), true, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), true, "charlie has voted");
        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded), "proposal not succeeded"
        );

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod() + 1);
        vm.expectEmit();
        emit ProposalAnnouncement.ProposalAnnounced();
        vm.expectEmit();
        emit IGovernor.ProposalExecuted(proposalId);
        turnkeyGovernor.execute(targets, values, calldatas, keccak256(bytes(description)));
    }

    function test_propose_vote_defeated_success() public {
        ProposalAnnouncement proposalAnnouncement = new ProposalAnnouncement();

        mintAndDelegate(alice, alice, defaultProposalThreshold);
        mintAndDelegate(bob, bob, defaultProposalThreshold);
        mintAndDelegate(charlie, charlie, defaultProposalThreshold);

        address[] memory targets = new address[](1);
        targets[0] = address(proposalAnnouncement);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(ProposalAnnouncement.announceProposal.selector);

        string memory description = "test";
        vm.warp(block.timestamp + 1); // make delegated votes active
        uint256 proposalId = turnkeyGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        vm.startPrank(alice);
        vm.expectEmit(address(turnkeyGovernor));
        emit IGovernor.ProposalCreated(
            proposalId,
            alice,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            block.timestamp + turnkeyGovernor.votingDelay(),
            block.timestamp + turnkeyGovernor.votingPeriod() + turnkeyGovernor.votingDelay(),
            description
        );
        turnkeyGovernor.propose(targets, values, calldatas, description);
        vm.stopPrank();

        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Pending), "proposal not pending"
        );
        vm.warp(block.timestamp + turnkeyGovernor.votingDelay() + 1);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), false, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), false, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), false, "charlie has voted");
        assertEq(uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Active), "proposal not active");

        vm.prank(alice);
        turnkeyGovernor.castVote(proposalId, 1);

        vm.prank(bob);
        turnkeyGovernor.castVote(proposalId, 0);

        vm.prank(charlie);
        turnkeyGovernor.castVote(proposalId, 0);

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod());
        vm.prank(alice);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), true, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), true, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), true, "charlie has voted");
        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Defeated), "proposal not succeeded"
        );

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod() + 1);
        vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorUnexpectedProposalState.selector, proposalId, 3, 48));
        turnkeyGovernor.execute(targets, values, calldatas, keccak256(bytes(description)));
    }

    function test_propose_vote_no_quorum_success() public {
        ProposalAnnouncement proposalAnnouncement = new ProposalAnnouncement();

        address dan = makeAddr("dan");
        mintAndDelegate(alice, alice, defaultProposalThreshold);
        mintAndDelegate(bob, bob, defaultProposalThreshold);
        mintAndDelegate(charlie, charlie, defaultProposalThreshold);
        mintAndDelegate(dan, dan, defaultProposalThreshold * 97);

        address[] memory targets = new address[](1);
        targets[0] = address(proposalAnnouncement);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(ProposalAnnouncement.announceProposal.selector);

        string memory description = "test";
        vm.warp(block.timestamp + 1); // make delegated votes active
        uint256 proposalId = turnkeyGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        vm.startPrank(alice);
        vm.expectEmit(address(turnkeyGovernor));
        emit IGovernor.ProposalCreated(
            proposalId,
            alice,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            block.timestamp + turnkeyGovernor.votingDelay(),
            block.timestamp + turnkeyGovernor.votingPeriod() + turnkeyGovernor.votingDelay(),
            description
        );
        turnkeyGovernor.propose(targets, values, calldatas, description);
        vm.stopPrank();

        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Pending), "proposal not pending"
        );
        vm.warp(block.timestamp + turnkeyGovernor.votingDelay() + 1);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), false, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), false, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), false, "charlie has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(dan)), false, "dan has voted");
        assertEq(uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Active), "proposal not active");

        vm.prank(alice);
        turnkeyGovernor.castVote(proposalId, 1);

        vm.prank(bob);
        turnkeyGovernor.castVote(proposalId, 1);

        vm.prank(charlie);
        turnkeyGovernor.castVote(proposalId, 1);

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod());
        vm.prank(alice);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), true, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), true, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), true, "charlie has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(dan)), false, "dan has voted");
        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Defeated), "proposal not succeeded"
        );

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod() + 1);
        vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorUnexpectedProposalState.selector, proposalId, 3, 48));
        turnkeyGovernor.execute(targets, values, calldatas, keccak256(bytes(description)));
    }

    function test_propose_vote_late_quorum_success() public {
        ProposalAnnouncement proposalAnnouncement = new ProposalAnnouncement();

        address dan = makeAddr("dan");
        mintAndDelegate(alice, alice, defaultProposalThreshold);
        mintAndDelegate(bob, bob, defaultProposalThreshold);
        mintAndDelegate(charlie, charlie, defaultProposalThreshold);
        mintAndDelegate(dan, dan, defaultProposalThreshold * 100);

        address[] memory targets = new address[](1);
        targets[0] = address(proposalAnnouncement);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(ProposalAnnouncement.announceProposal.selector);

        string memory description = "test";
        vm.warp(block.timestamp + 1); // make delegated votes active

        console.log("timestamp", block.timestamp);
        uint256 proposalId = turnkeyGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        vm.startPrank(alice);
        vm.expectEmit(address(turnkeyGovernor));
        emit IGovernor.ProposalCreated(
            proposalId,
            alice,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            block.timestamp + turnkeyGovernor.votingDelay(),
            block.timestamp + turnkeyGovernor.votingPeriod() + turnkeyGovernor.votingDelay(),
            description
        );
        turnkeyGovernor.propose(targets, values, calldatas, description);
        vm.stopPrank();

        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Pending), "proposal not pending"
        );
        vm.warp(block.timestamp + turnkeyGovernor.votingDelay() + 1);

        assertTrue(
            turnkeyGovernor.quorum(turnkeyGovernor.proposalSnapshot(proposalId))
                <= turnkeyERC20.getPastVotes(dan, turnkeyGovernor.clock() - 1),
            "quorum is greater than dan's balance"
        );

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), false, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), false, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), false, "charlie has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(dan)), false, "dan has voted");
        assertEq(uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Active), "proposal not active");

        vm.prank(alice);
        turnkeyGovernor.castVote(proposalId, 0);

        vm.prank(bob);
        turnkeyGovernor.castVote(proposalId, 0);

        vm.prank(charlie);
        turnkeyGovernor.castVote(proposalId, 0);

        assertEq(
            turnkeyGovernor.proposalDeadline(proposalId),
            block.timestamp + turnkeyGovernor.votingPeriod() - 1,
            "proposal deadline is not correct"
        );

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod() - 1);

        vm.startPrank(dan);
        vm.expectEmit();
        emit GovernorPreventLateQuorum.ProposalExtended(
            proposalId, uint64(turnkeyGovernor.proposalDeadline(proposalId) + turnkeyGovernor.lateQuorumVoteExtension())
        );
        turnkeyGovernor.castVote(proposalId, 1);
        vm.stopPrank();
        assertEq(
            turnkeyGovernor.proposalDeadline(proposalId),
            block.timestamp + turnkeyGovernor.lateQuorumVoteExtension(),
            "proposal eta is not correct"
        );

        // warp past the lateQuorumVoteExtension activated by Dan's vote
        vm.warp(block.timestamp + turnkeyGovernor.lateQuorumVoteExtension() + 1);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), true, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), true, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), true, "charlie has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(dan)), true, "dan has voted");
        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded), "proposal not succeeded"
        );

        vm.expectEmit();
        emit ProposalAnnouncement.ProposalAnnounced();
        vm.expectEmit();
        emit IGovernor.ProposalExecuted(proposalId);
        turnkeyGovernor.execute(targets, values, calldatas, keccak256(bytes(description)));
    }

    function test_propose_modify_votingDelay_success() public {
        mintAndDelegate(alice, alice, defaultProposalThreshold);
        mintAndDelegate(bob, alice, defaultProposalThreshold);
        mintAndDelegate(charlie, alice, defaultProposalThreshold);

        address[] memory targets = new address[](1);
        targets[0] = address(turnkeyGovernor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        uint48 newVotingDelay = 100;
        calldatas[0] = abi.encodeWithSelector(GovernorSettings.setVotingDelay.selector, newVotingDelay);

        string memory description = "test";
        vm.warp(block.timestamp + 1); // make delegated votes active
        uint256 proposalId = turnkeyGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        vm.startPrank(alice);
        vm.expectEmit(address(turnkeyGovernor));
        emit IGovernor.ProposalCreated(
            proposalId,
            alice,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            block.timestamp + turnkeyGovernor.votingDelay(),
            block.timestamp + turnkeyGovernor.votingPeriod() + turnkeyGovernor.votingDelay(),
            description
        );
        turnkeyGovernor.propose(targets, values, calldatas, description);
        vm.stopPrank();

        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Pending), "proposal not pending"
        );
        vm.warp(block.timestamp + turnkeyGovernor.votingDelay() + 1);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), false, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), false, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), false, "charlie has voted");
        assertEq(uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Active), "proposal not active");

        vm.prank(alice);
        turnkeyGovernor.castVote(proposalId, 1);

        vm.prank(bob);
        turnkeyGovernor.castVote(proposalId, 0);

        vm.prank(charlie);
        turnkeyGovernor.castVote(proposalId, 1);

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod());
        vm.prank(alice);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), true, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), true, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), true, "charlie has voted");
        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded), "proposal not succeeded"
        );

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod() + 1);
        vm.expectEmit();
        emit GovernorSettings.VotingDelaySet(turnkeyGovernor.votingDelay(), newVotingDelay);
        vm.expectEmit();
        emit IGovernor.ProposalExecuted(proposalId);
        turnkeyGovernor.execute(targets, values, calldatas, keccak256(bytes(description)));

        assertEq(turnkeyGovernor.votingDelay(), newVotingDelay, "voting delay is not correct");
    }

    function test_propose_modify_votingPeriod_success() public {
        mintAndDelegate(alice, alice, defaultProposalThreshold);
        mintAndDelegate(bob, alice, defaultProposalThreshold);
        mintAndDelegate(charlie, alice, defaultProposalThreshold);

        address[] memory targets = new address[](1);
        targets[0] = address(turnkeyGovernor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        uint32 newVotingPeriod = 100;
        calldatas[0] = abi.encodeWithSelector(GovernorSettings.setVotingPeriod.selector, newVotingPeriod);

        string memory description = "test";
        vm.warp(block.timestamp + 1); // make delegated votes active
        uint256 proposalId = turnkeyGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        vm.startPrank(alice);
        vm.expectEmit(address(turnkeyGovernor));
        emit IGovernor.ProposalCreated(
            proposalId,
            alice,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            block.timestamp + turnkeyGovernor.votingDelay(),
            block.timestamp + turnkeyGovernor.votingPeriod() + turnkeyGovernor.votingDelay(),
            description
        );
        turnkeyGovernor.propose(targets, values, calldatas, description);
        vm.stopPrank();

        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Pending), "proposal not pending"
        );
        vm.warp(block.timestamp + turnkeyGovernor.votingDelay() + 1);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), false, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), false, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), false, "charlie has voted");
        assertEq(uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Active), "proposal not active");

        vm.prank(alice);
        turnkeyGovernor.castVote(proposalId, 1);

        vm.prank(bob);
        turnkeyGovernor.castVote(proposalId, 0);

        vm.prank(charlie);
        turnkeyGovernor.castVote(proposalId, 1);

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod());
        vm.prank(alice);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), true, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), true, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), true, "charlie has voted");
        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded), "proposal not succeeded"
        );

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod() + 1);
        vm.expectEmit();
        emit GovernorSettings.VotingPeriodSet(turnkeyGovernor.votingPeriod(), newVotingPeriod);
        vm.expectEmit();
        emit IGovernor.ProposalExecuted(proposalId);
        turnkeyGovernor.execute(targets, values, calldatas, keccak256(bytes(description)));

        assertEq(turnkeyGovernor.votingPeriod(), newVotingPeriod, "voting period is not correct");
    }

    function test_propose_modify_proposalThreshold_success() public {
        mintAndDelegate(alice, alice, defaultProposalThreshold);
        mintAndDelegate(bob, alice, defaultProposalThreshold);
        mintAndDelegate(charlie, alice, defaultProposalThreshold);

        address[] memory targets = new address[](1);
        targets[0] = address(turnkeyGovernor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        uint256 newProposalThreshold = 100;
        calldatas[0] = abi.encodeWithSelector(GovernorSettings.setProposalThreshold.selector, newProposalThreshold);

        string memory description = "test";
        vm.warp(block.timestamp + 1); // make delegated votes active
        uint256 proposalId = turnkeyGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        vm.startPrank(alice);
        vm.expectEmit(address(turnkeyGovernor));
        emit IGovernor.ProposalCreated(
            proposalId,
            alice,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            block.timestamp + turnkeyGovernor.votingDelay(),
            block.timestamp + turnkeyGovernor.votingPeriod() + turnkeyGovernor.votingDelay(),
            description
        );
        turnkeyGovernor.propose(targets, values, calldatas, description);
        vm.stopPrank();

        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Pending), "proposal not pending"
        );
        vm.warp(block.timestamp + turnkeyGovernor.votingDelay() + 1);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), false, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), false, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), false, "charlie has voted");
        assertEq(uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Active), "proposal not active");

        vm.prank(alice);
        turnkeyGovernor.castVote(proposalId, 1);

        vm.prank(bob);
        turnkeyGovernor.castVote(proposalId, 0);

        vm.prank(charlie);
        turnkeyGovernor.castVote(proposalId, 1);

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod());
        vm.prank(alice);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), true, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), true, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), true, "charlie has voted");
        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded), "proposal not succeeded"
        );

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod() + 1);
        vm.expectEmit();
        emit GovernorSettings.ProposalThresholdSet(turnkeyGovernor.proposalThreshold(), newProposalThreshold);
        vm.expectEmit();
        emit IGovernor.ProposalExecuted(proposalId);
        turnkeyGovernor.execute(targets, values, calldatas, keccak256(bytes(description)));

        assertEq(turnkeyGovernor.proposalThreshold(), newProposalThreshold, "proposal threshold is not correct");
    }

    function test_propose_modify_quorumPercentage_success() public {
        mintAndDelegate(alice, alice, defaultProposalThreshold);
        mintAndDelegate(bob, alice, defaultProposalThreshold);
        mintAndDelegate(charlie, alice, defaultProposalThreshold);

        address[] memory targets = new address[](1);
        targets[0] = address(turnkeyGovernor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        uint256 newQuorumPercentage = 100;
        calldatas[0] =
            abi.encodeWithSelector(GovernorVotesQuorumFraction.updateQuorumNumerator.selector, newQuorumPercentage);

        string memory description = "test";
        vm.warp(block.timestamp + 1); // make delegated votes active
        uint256 proposalId = turnkeyGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        vm.startPrank(alice);
        vm.expectEmit(address(turnkeyGovernor));
        emit IGovernor.ProposalCreated(
            proposalId,
            alice,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            block.timestamp + turnkeyGovernor.votingDelay(),
            block.timestamp + turnkeyGovernor.votingPeriod() + turnkeyGovernor.votingDelay(),
            description
        );
        turnkeyGovernor.propose(targets, values, calldatas, description);
        vm.stopPrank();

        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Pending), "proposal not pending"
        );
        vm.warp(block.timestamp + turnkeyGovernor.votingDelay() + 1);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), false, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), false, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), false, "charlie has voted");
        assertEq(uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Active), "proposal not active");

        vm.prank(alice);
        turnkeyGovernor.castVote(proposalId, 1);

        vm.prank(bob);
        turnkeyGovernor.castVote(proposalId, 0);

        vm.prank(charlie);
        turnkeyGovernor.castVote(proposalId, 1);

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod());
        vm.prank(alice);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), true, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), true, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), true, "charlie has voted");
        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded), "proposal not succeeded"
        );

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod() + 1);
        vm.expectEmit();
        emit GovernorVotesQuorumFraction.QuorumNumeratorUpdated(turnkeyGovernor.quorumNumerator(), newQuorumPercentage);
        vm.expectEmit();
        emit IGovernor.ProposalExecuted(proposalId);
        turnkeyGovernor.execute(targets, values, calldatas, keccak256(bytes(description)));

        assertEq(turnkeyGovernor.quorumNumerator(), newQuorumPercentage, "quorum percentage is not correct");
    }

    function test_propose_modify_voteExtension_success() public {
        mintAndDelegate(alice, alice, defaultProposalThreshold);
        mintAndDelegate(bob, alice, defaultProposalThreshold);
        mintAndDelegate(charlie, alice, defaultProposalThreshold);

        address[] memory targets = new address[](1);
        targets[0] = address(turnkeyGovernor);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        uint48 newVoteExtension = 100;
        calldatas[0] =
            abi.encodeWithSelector(GovernorPreventLateQuorum.setLateQuorumVoteExtension.selector, newVoteExtension);

        string memory description = "test";
        vm.warp(block.timestamp + 1); // make delegated votes active
        uint256 proposalId = turnkeyGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        vm.startPrank(alice);
        vm.expectEmit(address(turnkeyGovernor));
        emit IGovernor.ProposalCreated(
            proposalId,
            alice,
            targets,
            values,
            new string[](targets.length),
            calldatas,
            block.timestamp + turnkeyGovernor.votingDelay(),
            block.timestamp + turnkeyGovernor.votingPeriod() + turnkeyGovernor.votingDelay(),
            description
        );
        turnkeyGovernor.propose(targets, values, calldatas, description);
        vm.stopPrank();

        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Pending), "proposal not pending"
        );
        vm.warp(block.timestamp + turnkeyGovernor.votingDelay() + 1);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), false, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), false, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), false, "charlie has voted");
        assertEq(uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Active), "proposal not active");

        vm.prank(alice);
        turnkeyGovernor.castVote(proposalId, 1);

        vm.prank(bob);
        turnkeyGovernor.castVote(proposalId, 0);

        vm.prank(charlie);
        turnkeyGovernor.castVote(proposalId, 1);

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod());
        vm.prank(alice);

        assertEq(turnkeyGovernor.hasVoted(proposalId, address(alice)), true, "alice has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(bob)), true, "bob has voted");
        assertEq(turnkeyGovernor.hasVoted(proposalId, address(charlie)), true, "charlie has voted");
        assertEq(
            uint8(turnkeyGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded), "proposal not succeeded"
        );

        vm.warp(block.timestamp + turnkeyGovernor.votingPeriod() + 1);
        vm.expectEmit();
        emit GovernorPreventLateQuorum.LateQuorumVoteExtensionSet(
            turnkeyGovernor.lateQuorumVoteExtension(), newVoteExtension
        );
        vm.expectEmit();
        emit IGovernor.ProposalExecuted(proposalId);
        turnkeyGovernor.execute(targets, values, calldatas, keccak256(bytes(description)));

        assertEq(turnkeyGovernor.lateQuorumVoteExtension(), newVoteExtension, "vote extension is not correct");
    }

    function test_CLOCKMODE_success() public {
        assertEq(turnkeyGovernor.CLOCK_MODE(), "mode=timestamp", "CLOCKMODE is not correct");
    }

    function test_quorum_success() public {
        mintAndDelegate(alice, alice, defaultProposalThreshold);
        mintAndDelegate(bob, alice, defaultProposalThreshold);
        mintAndDelegate(charlie, alice, defaultProposalThreshold);

        vm.warp(block.timestamp + 1);

        assertEq(
            turnkeyGovernor.quorum(block.timestamp - 1),
            3 * defaultProposalThreshold * defaultQuorumPercentage / 100,
            "quorum is not correct"
        );
    }

    function mintAndDelegate(address to, address delegate, uint256 amount) public {
        vm.prank(initialOwner.addr);
        turnkeyERC20.mint(to, amount);
        vm.prank(to);
        turnkeyERC20.delegate(delegate);
    }
}

contract ProposalAnnouncement {
    event ProposalAnnounced();

    function announceProposal() external {
        emit ProposalAnnounced();
    }
}
