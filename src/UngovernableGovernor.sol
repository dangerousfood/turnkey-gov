// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.26;

import {IGovernor, Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from
    "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorPreventLateQuorum} from "@openzeppelin/contracts/governance/extensions/GovernorPreventLateQuorum.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/// @title UngovernableGovernor is a boilerplate composition of the Governor contract set from OpenZeppelin
contract UngovernableGovernor is
    Governor,
    GovernorVotes,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotesQuorumFraction,
    GovernorPreventLateQuorum
{
    /// @notice The constructor for UngovernableGovernor
    /// @param _initialQuorumPercentage The quorum percentage for the governor (0-100) the minimum percentage of votes required to reach quorum for a proposal to succeed
    /// @param _initialVoteExtension The vote extension for the governor when a late quorum is reached, the proposal will be queued for an additional _voteExtension seconds
    /// @param _initialVotingDelay The initial voting delay before a proposal is voted on (seconds)
    /// @param _initialVotingPeriod The initial voting period for a proposal (duration that voting occurs in seconds)
    /// @param _initialProposalThreshold The initial proposal threshold for the governor (minimum number of votes required to create a proposal in wei)
    constructor(
        string memory _name,
        IVotes _token,
        uint256 _initialQuorumPercentage,
        uint48 _initialVoteExtension,
        uint48 _initialVotingDelay,
        uint32 _initialVotingPeriod,
        uint256 _initialProposalThreshold
    )
        Governor(_name)
        GovernorVotes(_token)
        GovernorSettings(_initialVotingDelay, _initialVotingPeriod, _initialProposalThreshold)
        GovernorVotesQuorumFraction(_initialQuorumPercentage)
        GovernorPreventLateQuorum(_initialVoteExtension)
    {}

    /// @inheritdoc GovernorSettings
    function votingDelay() public view override(GovernorSettings, Governor) returns (uint256) {
        return GovernorSettings.votingDelay();
    }

    /// @inheritdoc GovernorSettings
    function votingPeriod() public view override(GovernorSettings, Governor) returns (uint256) {
        return GovernorSettings.votingPeriod();
    }

    /// @inheritdoc GovernorSettings
    function proposalThreshold() public view override(GovernorSettings, Governor) returns (uint256) {
        return GovernorSettings.proposalThreshold();
    }

    /// @inheritdoc GovernorVotesQuorumFraction
    function quorum(uint256 timepoint) public view override(GovernorVotesQuorumFraction, Governor) returns (uint256) {
        return GovernorVotesQuorumFraction.quorum(timepoint);
    }

    /// @inheritdoc Governor
    function CLOCK_MODE() public pure virtual override(Governor, GovernorVotes) returns (string memory) {
        return "mode=timestamp";
    }

    /// @inheritdoc Governor
    /// @dev Overridden to  use a timestamp clock mode
    function clock() public view virtual override(Governor, GovernorVotes) returns (uint48 result) {
        return uint48(block.timestamp);
    }

    /// @inheritdoc GovernorPreventLateQuorum
    function _tallyUpdated(uint256 proposalId) internal virtual override(GovernorPreventLateQuorum, Governor) {
        GovernorPreventLateQuorum._tallyUpdated(proposalId);
    }

    /// @inheritdoc GovernorPreventLateQuorum
    function proposalDeadline(uint256 proposalId)
        public
        view
        virtual
        override(GovernorPreventLateQuorum, Governor)
        returns (uint256)
    {
        return GovernorPreventLateQuorum.proposalDeadline(proposalId);
    }
}
