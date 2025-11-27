// TODO:
// Let evaluators hold governance tokens?
// WIll evaluators be incentivized through governance tokens?
// Add events

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {EvaluatorSBT} from "@src/tokens/EvaluatorSBT.sol";

contract EvaluatorGovernor {
    error EvaluatorGovernor__ZeroAddressNotAllowed();
    error EvaluatorGovernor__ReputationOutOfRange();
    error EvaluatorGovernor__VoteOutOfRange();
    error EvaluatorGovernor__ProposalDoesNotExist();
    error EvaluatorGovernor__VotingPeriodOver();
    error EvaluatorGovernor__AlreadyVoted();
    error EvaluatorGovernor__NoVotes();
    error EvaluatorGovernor__QuorumNotMet();
    error EvaluatorGovernor__VotingOngoing();
    error EvaluatorGovernor__AlreadyExecuted();
    error EvaluatorGovernor__ZeroReputation();
    error EvaluatorGovernor__ProposalNotFinalized();

    EvaluatorSBT public evaluatorSbt;

    uint256 public s_proposalId = 1;
    mapping(uint256 => EvaluatorProposal) private s_evaluatorProposals;
    mapping(uint256 => ImpactProposal) private s_impactProposals;
    mapping(uint256 => mapping(address => bool)) private s_hasVoted;
    // roundId => projectId => impactProposalId
    mapping(uint256 => mapping(uint256 => uint256))
        public impactProposalIdForProject;

    uint8 private MIN_PARTICIPATION_PERCENT = 60;
    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant YES_ADD_EVALUATOR = 55;
    uint256 public constant YES_REMOVE_EVALUATOR = 66;
    uint256 public constant YES_ADJUST_REP = 60;

    address public immutable i_roundManager;

    modifier onlyEvaluator() {
        require(evaluatorSbt.isEvaluator(msg.sender), "Should be an evaluator");
        _;
    }

    modifier targetIsEvaluator(address _target) {
        require(
            evaluatorSbt.isEvaluator(_target),
            "Target address should be an evaluator"
        );
        _;
    }

    modifier onlyRoundManager() {
        require(
            msg.sender == i_roundManager,
            "Only RoundManager can call this function."
        );
        _;
    }

    enum ProposalType {
        AddEvaluator,
        RemoveEvaluator,
        AdjustReputation
    }

    struct EvaluatorProposal {
        ProposalType proposalType;
        address targetEvaluator;
        uint8 newReputation;
        uint256 startTime;
        uint256 endTime;
        uint256 yesVotes;
        uint256 noVotes;
    }

    struct ImpactProposal {
        uint256 roundId;
        uint256 projectId;
        uint256 startTime;
        uint256 endTime;
        bool finalized;
        uint256 sumWeighted; // Σ (reputiation * score)
        uint256 sumWeights; // Σ reputation
        uint256 impactScore;
        uint256 totalVotes;
    }

    constructor(
        address[] memory _initialEvaluators,
        uint8[] memory _initialReputations,
        address _roundManager
    ) {
        evaluatorSbt = new EvaluatorSBT(
            _initialEvaluators,
            _initialReputations,
            address(this)
        );
        i_roundManager = _roundManager;
    }

    function proposeAddEvaluator(
        address _evaluator,
        uint8 _reputation
    ) external onlyEvaluator returns (uint256) {
        if (_evaluator == address(0)) {
            revert EvaluatorGovernor__ZeroAddressNotAllowed();
        }
        if (_reputation == 0 || _reputation > 100) {
            revert EvaluatorGovernor__ReputationOutOfRange();
        }
        uint256 id = s_proposalId++;
        s_evaluatorProposals[id] = EvaluatorProposal({
            proposalType: ProposalType.AddEvaluator,
            targetEvaluator: _evaluator,
            newReputation: _reputation,
            startTime: block.timestamp,
            endTime: block.timestamp + VOTING_PERIOD,
            yesVotes: 0,
            noVotes: 0
        });
        return id;
    }

    function proposeRemoveEvaluator(
        address _evaluator
    ) external onlyEvaluator targetIsEvaluator(_evaluator) returns (uint256) {
        uint256 id = s_proposalId++;
        s_evaluatorProposals[id] = EvaluatorProposal({
            proposalType: ProposalType.RemoveEvaluator,
            targetEvaluator: _evaluator,
            newReputation: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + VOTING_PERIOD,
            yesVotes: 0,
            noVotes: 0
        });
        return id;
    }

    function proposeAdjustReputation(
        address _evaluator,
        uint8 _reputation
    ) external onlyEvaluator targetIsEvaluator(_evaluator) returns (uint256) {
        uint256 id = s_proposalId++;
        s_evaluatorProposals[id] = EvaluatorProposal({
            proposalType: ProposalType.AdjustReputation,
            targetEvaluator: _evaluator,
            newReputation: _reputation,
            startTime: block.timestamp,
            endTime: block.timestamp + VOTING_PERIOD,
            yesVotes: 0,
            noVotes: 0
        });
        return id;
    }

    function proposeImpactEval(
        uint256 _roundId,
        uint256 _projectId,
        uint256 _votingPeriod
    ) external onlyRoundManager returns (uint256) {
        uint256 id = s_proposalId++;
        s_impactProposals[id] = ImpactProposal({
            roundId: _roundId,
            projectId: _projectId,
            startTime: block.timestamp,
            endTime: block.timestamp + _votingPeriod,
            finalized: false,
            sumWeighted: 0,
            sumWeights: 0,
            impactScore: 0,
            totalVotes: 0
        });
        impactProposalIdForProject[_roundId][_projectId] = id;
        return id;
    }

    function voteEvaluator(
        uint256 _proposalId,
        uint8 _vote
    ) external onlyEvaluator {
        EvaluatorProposal storage proposal = s_evaluatorProposals[_proposalId];

        if (proposal.startTime == 0) {
            revert EvaluatorGovernor__ProposalDoesNotExist();
        }

        if (block.timestamp >= proposal.endTime) {
            revert EvaluatorGovernor__VotingPeriodOver();
        }

        if (s_hasVoted[_proposalId][msg.sender]) {
            revert EvaluatorGovernor__AlreadyVoted();
        }

        if (_vote == 0) {
            proposal.noVotes += 1;
        } else if (_vote == 1) {
            proposal.yesVotes += 1;
        } else {
            revert EvaluatorGovernor__VoteOutOfRange();
        }

        s_hasVoted[_proposalId][msg.sender] = true;
    }

    function voteProjectImpact(
        uint256 _proposalId,
        uint8 _score
    ) external onlyEvaluator {
        ImpactProposal storage proposal = s_impactProposals[_proposalId];
        if (proposal.roundId == 0) {
            revert EvaluatorGovernor__ProposalDoesNotExist();
        }

        if (block.timestamp >= proposal.endTime) {
            revert EvaluatorGovernor__VotingPeriodOver();
        }

        if (s_hasVoted[_proposalId][msg.sender]) {
            revert EvaluatorGovernor__AlreadyVoted();
        }

        if (_score > 100) {
            revert EvaluatorGovernor__VoteOutOfRange();
        }

        uint8 reputation = evaluatorSbt.getReputation(msg.sender);
        if (reputation == 0) {
            revert EvaluatorGovernor__ZeroReputation();
        }

        proposal.sumWeighted += _score * reputation;
        proposal.sumWeights += reputation;
        proposal.totalVotes += 1;
        s_hasVoted[_proposalId][msg.sender] = true;
    }

    function executeEvaluatorProposal(uint256 _proposalId) external {
        EvaluatorProposal storage proposal = s_evaluatorProposals[_proposalId];

        if (proposal.startTime == 0) {
            revert EvaluatorGovernor__ProposalDoesNotExist();
        }

        if (block.timestamp < proposal.endTime) {
            revert EvaluatorGovernor__VotingOngoing();
        }

        uint256 votesTotal = proposal.yesVotes + proposal.noVotes;
        if (votesTotal == 0) {
            revert EvaluatorGovernor__NoVotes();
        }
        uint256 percentageYes = (proposal.yesVotes * 100) / votesTotal;

        uint256 totalEvaluators = evaluatorSbt.getEvaluatorCount();
        if (votesTotal * 100 < totalEvaluators * MIN_PARTICIPATION_PERCENT) {
            revert EvaluatorGovernor__QuorumNotMet();
        }

        if (proposal.proposalType == ProposalType.AddEvaluator) {
            if (percentageYes < YES_ADD_EVALUATOR) {
                delete s_evaluatorProposals[_proposalId];
            } else {
                evaluatorSbt.mintEvaluator(
                    proposal.targetEvaluator,
                    uint8(proposal.newReputation)
                );
                delete s_evaluatorProposals[_proposalId];
            }
        }
        if (proposal.proposalType == ProposalType.RemoveEvaluator) {
            if (percentageYes < YES_REMOVE_EVALUATOR) {
                delete s_evaluatorProposals[_proposalId];
            } else {
                evaluatorSbt.burnEvaluator(proposal.targetEvaluator);
                delete s_evaluatorProposals[_proposalId];
            }
        }
        if (proposal.proposalType == ProposalType.AdjustReputation) {
            if (percentageYes < YES_ADJUST_REP) {
                delete s_evaluatorProposals[_proposalId];
            } else {
                evaluatorSbt.adjustReputation(
                    proposal.targetEvaluator,
                    uint8(proposal.newReputation)
                );
                delete s_evaluatorProposals[_proposalId];
            }
        }
    }

    function executeImpactProposal(uint256 _proposalId) external {
        ImpactProposal storage proposal = s_impactProposals[_proposalId];

        if (s_impactProposals[_proposalId].roundId == 0) {
            revert EvaluatorGovernor__ProposalDoesNotExist();
        }

        if (block.timestamp < proposal.endTime) {
            revert EvaluatorGovernor__VotingOngoing();
        }

        if (proposal.finalized == true) {
            revert EvaluatorGovernor__AlreadyExecuted();
        }

        if (proposal.sumWeights == 0) {
            revert EvaluatorGovernor__NoVotes();
        }

        uint256 totalEvaluators = evaluatorSbt.getEvaluatorCount();
        if (
            proposal.totalVotes * 100 <
            totalEvaluators * MIN_PARTICIPATION_PERCENT
        ) {
            revert EvaluatorGovernor__QuorumNotMet();
        }

        uint256 impactScore = proposal.sumWeighted / proposal.sumWeights;
        proposal.impactScore = impactScore;
        proposal.finalized = true;
    }

    function getImpactScore(
        uint256 _proposalId
    ) external view returns (uint256) {
        return s_impactProposals[_proposalId].impactScore;
    }

    function getEvaluatorProposal(
        uint256 id
    ) external view returns (EvaluatorProposal memory) {
        return s_evaluatorProposals[id];
    }

    function getImpactProposal(
        uint256 id
    ) external view returns (ImpactProposal memory) {
        return s_impactProposals[id];
    }

    function hasVoted(
        uint256 proposalId,
        address voter
    ) external view returns (bool) {
        return s_hasVoted[proposalId][voter];
    }

    function getImpactScoreForProject(
        uint256 _roundId,
        uint256 _projectId
    ) external view returns (uint256) {
        uint256 proposalId = impactProposalIdForProject[_roundId][_projectId];
        if (proposalId == 0) {
            revert EvaluatorGovernor__ProposalDoesNotExist();
        }
        if (!s_impactProposals[proposalId].finalized) {
            revert EvaluatorGovernor__ProposalNotFinalized();
        }
        return s_impactProposals[proposalId].impactScore;
    }
}
