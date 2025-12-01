// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {EvaluatorSBT} from "@src/tokens/EvaluatorSBT.sol";
import {IEvaluatorGovernor} from "@src/Interfaces.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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

contract EvaluatorGovernor is IEvaluatorGovernor, ReentrancyGuard {
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

    enum ProposalType {
        AddEvaluator,
        RemoveEvaluator,
        AdjustReputation
    }

    uint256 private s_proposalId = 1;
    uint8 private MIN_PARTICIPATION_PERCENT = 60;
    uint256 private constant VOTING_PERIOD = 3 days;
    uint256 private constant YES_ADD_EVALUATOR = 55;
    uint256 private constant YES_REMOVE_EVALUATOR = 66;
    uint256 private constant YES_ADJUST_REP = 60;

    mapping(uint256 => EvaluatorProposal) private s_evaluatorProposals;
    mapping(uint256 => ImpactProposal) private s_impactProposals;
    mapping(uint256 => mapping(address => bool)) private s_hasVoted;
    // roundId => projectId => impactProposalId
    mapping(uint256 => mapping(uint256 => uint256))
        private s_impactProposalIdForProject;

    EvaluatorSBT private immutable i_evaluatorSbt;

    event AddEvaluatorProposalAdded(
        uint256 indexed id,
        address indexed evaluator,
        uint8 reputation,
        uint256 endTime
    );

    event RemoveEvaluatorPropoalAdded(
        uint256 indexed id,
        address indexed evaluator,
        uint256 endTime
    );

    event ImpactEvaluationProposalAdded(
        uint256 indexed id,
        uint256 indexed roundId,
        uint256 projectId,
        uint256 endTime
    );

    event ReputationAdjustmentProposalAdded(
        uint256 indexed id,
        address indexed evaluator,
        uint8 reputation,
        uint256 endTime
    );

    event VotedOnEvaluator(uint256 indexed proposalId, uint8 indexed vote);
    event VotedProjectImpact(uint256 indexed proposalId, uint8 indexed score);
    event EvaluatorProposalExecuted(uint256 indexed proposalId);
    event ImpactProposalExecuted(uint256 indexed proposalId);

    modifier onlyEvaluator() {
        require(
            i_evaluatorSbt.isEvaluator(msg.sender),
            "Should be an evaluator"
        );
        _;
    }

    modifier targetIsEvaluator(address _target) {
        require(
            i_evaluatorSbt.isEvaluator(_target),
            "Target address should be an evaluator"
        );
        _;
    }

    constructor(
        address[] memory _initialEvaluators,
        uint8[] memory _initialReputations
    ) {
        i_evaluatorSbt = new EvaluatorSBT(
            _initialEvaluators,
            _initialReputations,
            address(this)
        );
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

        emit AddEvaluatorProposalAdded(
            id,
            _evaluator,
            _reputation,
            s_evaluatorProposals[id].endTime
        );

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

        emit RemoveEvaluatorPropoalAdded(
            id,
            _evaluator,
            s_evaluatorProposals[id].endTime
        );

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

        emit ReputationAdjustmentProposalAdded(
            id,
            _evaluator,
            _reputation,
            s_evaluatorProposals[id].endTime
        );

        return id;
    }

    function proposeImpactEval(
        uint256 _roundId,
        uint256 _projectId,
        uint256 _votingPeriod
    ) external returns (uint256) {
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
        s_impactProposalIdForProject[_roundId][_projectId] = id;

        emit ImpactEvaluationProposalAdded(
            id,
            _roundId,
            _projectId,
            s_impactProposals[id].endTime
        );

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

        emit VotedOnEvaluator(_proposalId, _vote);
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

        uint8 reputation = i_evaluatorSbt.getReputation(msg.sender);
        if (reputation == 0) {
            revert EvaluatorGovernor__ZeroReputation();
        }

        proposal.sumWeighted += _score * reputation;
        proposal.sumWeights += reputation;
        proposal.totalVotes += 1;
        s_hasVoted[_proposalId][msg.sender] = true;

        emit VotedProjectImpact(_proposalId, _score);
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

        uint256 totalEvaluators = i_evaluatorSbt.getEvaluatorCount();
        if (votesTotal * 100 < totalEvaluators * MIN_PARTICIPATION_PERCENT) {
            revert EvaluatorGovernor__QuorumNotMet();
        }

        if (proposal.proposalType == ProposalType.AddEvaluator) {
            if (percentageYes < YES_ADD_EVALUATOR) {
                delete s_evaluatorProposals[_proposalId];
            } else {
                i_evaluatorSbt.mintEvaluator(
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
                i_evaluatorSbt.burnEvaluator(proposal.targetEvaluator);
                delete s_evaluatorProposals[_proposalId];
            }
        }
        if (proposal.proposalType == ProposalType.AdjustReputation) {
            if (percentageYes < YES_ADJUST_REP) {
                delete s_evaluatorProposals[_proposalId];
            } else {
                i_evaluatorSbt.adjustReputation(
                    proposal.targetEvaluator,
                    uint8(proposal.newReputation)
                );
                delete s_evaluatorProposals[_proposalId];
            }
        }

        emit EvaluatorProposalExecuted(_proposalId);
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

        uint256 totalEvaluators = i_evaluatorSbt.getEvaluatorCount();
        if (
            proposal.totalVotes * 100 <
            totalEvaluators * MIN_PARTICIPATION_PERCENT
        ) {
            revert EvaluatorGovernor__QuorumNotMet();
        }

        uint256 impactScore = proposal.sumWeighted / proposal.sumWeights;
        proposal.impactScore = impactScore;
        proposal.finalized = true;

        emit ImpactProposalExecuted(_proposalId);
    }

    //----------------- Getter Functions -----------------//

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
        uint256 proposalId = s_impactProposalIdForProject[_roundId][_projectId];
        if (proposalId == 0) {
            revert EvaluatorGovernor__ProposalDoesNotExist();
        }
        if (!s_impactProposals[proposalId].finalized) {
            revert EvaluatorGovernor__ProposalNotFinalized();
        }
        return s_impactProposals[proposalId].impactScore;
    }

    function getEvaluatorSbt() external view returns (address) {
        return address(i_evaluatorSbt);
    }

    function getMinParticipationPercent() external view returns (uint8) {
        return MIN_PARTICIPATION_PERCENT;
    }

    function getVotingPeriod() external pure returns (uint256) {
        return VOTING_PERIOD;
    }

    function getYesThresholds()
        external
        pure
        returns (uint256, uint256, uint256)
    {
        return (YES_ADD_EVALUATOR, YES_REMOVE_EVALUATOR, YES_ADJUST_REP);
    }

    function getImpactProposalIdForProject(
        uint256 roundId,
        uint256 projectId
    ) external view returns (uint256) {
        return s_impactProposalIdForProject[roundId][projectId];
    }
}
