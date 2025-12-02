// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "forge-std/console.sol";
import "@test/utils/BaseTest.t.sol";
import {EvaluatorGovernor} from "@src/governance/evaluatorHouse/EvaluatorGovernor.sol";

contract TestEvaluatorSBT is BaseTest {
    uint256 public constant EVALUATOR_VOTING_PERIOD = 3 days;

    //--------------------- proposeAddEvaluator ---------------------//

    function testNonEvaluatorCantProposeAddEvaluator() external {
        address newEvaluator = makeAddr("New evaluator");
        uint8 newReputation = 66;

        vm.expectRevert("Should be an evaluator");
        evaluatorGovernor.proposeAddEvaluator(newEvaluator, newReputation);
    }

    function testProposeAddEvaluatorRevertsIfAddressZero() external {
        uint8 newReputation = 66;

        vm.expectRevert("EvaluatorGovernor__ZeroAddressNotAllowed()");
        vm.prank(evaluator1);
        evaluatorGovernor.proposeAddEvaluator(address(0), newReputation);
    }

    function testProposeAddEvaluatorRevertsIfReputationOutOfRange() external {
        address newEvaluator = makeAddr("New evaluator");
        uint8 newReputation = 166;

        vm.expectRevert("EvaluatorGovernor__ReputationOutOfRange()");
        vm.prank(evaluator1);
        evaluatorGovernor.proposeAddEvaluator(newEvaluator, newReputation);
    }

    function testProposeAddEvaluatorAddsANewProposal() external {
        address newEvaluator = makeAddr("New evaluator");
        uint8 newReputation = 66;

        vm.prank(evaluator1);
        evaluatorGovernor.proposeAddEvaluator(newEvaluator, newReputation);

        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();
        EvaluatorGovernor.EvaluatorProposal
            memory evaluatorProposal = evaluatorGovernor.getEvaluatorProposal(
                currentProposalId
            );
        assertEq(newEvaluator, evaluatorProposal.targetEvaluator);
    }

    function testProposeAddEvaluatorEmitsEvent() external {
        address newEvaluator = makeAddr("New evaluator");
        uint8 newReputation = 66;

        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();

        vm.expectEmit(address(evaluatorGovernor));
        emit EvaluatorGovernor.AddEvaluatorProposalAdded(
            currentProposalId + 1,
            newEvaluator,
            newReputation,
            block.timestamp + EVALUATOR_VOTING_PERIOD
        );

        vm.prank(evaluator1);
        evaluatorGovernor.proposeAddEvaluator(newEvaluator, newReputation);
    }

    //--------------------- proposeRemoveEvaluator ---------------------//
    function testProposeRemoveEvaluatorRevertsIfNotEvaluator() external {
        vm.expectRevert("Should be an evaluator");
        evaluatorGovernor.proposeRemoveEvaluator(evaluator1);
    }

    function testProposeRemoveEvaluatorRevertsIfTargetNotEvaluator() external {
        address absentEvaluator = makeAddr("Nonexistent Evaluator");
        vm.expectRevert("Target address should be an evaluator");
        vm.prank(evaluator1);
        evaluatorGovernor.proposeRemoveEvaluator(absentEvaluator);
    }

    function testProposeRemoveEvaluatorCreatesProposal() external {
        vm.prank(evaluator1);
        evaluatorGovernor.proposeRemoveEvaluator(evaluator2);

        uint256 id = evaluatorGovernor.getCurrentProposalId();
        EvaluatorGovernor.EvaluatorProposal memory proposal = evaluatorGovernor
            .getEvaluatorProposal(id);
        assertEq(evaluator2, proposal.targetEvaluator);
    }

    function testProposeRemoveEvaluatorEmitsEvent() external {
        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();

        vm.expectEmit(address(evaluatorGovernor));
        emit EvaluatorGovernor.RemoveEvaluatorPropoalAdded(
            currentProposalId + 1,
            evaluator2,
            block.timestamp + EVALUATOR_VOTING_PERIOD
        );

        vm.prank(evaluator1);
        evaluatorGovernor.proposeRemoveEvaluator(evaluator2);
    }

    //--------------------- proposeAdjustReputation ---------------------//

    function testOnlyEvaluatorCanProposeAdjustReputation() external {
        uint8 newReputation = 14;

        vm.expectRevert("Should be an evaluator");
        evaluatorGovernor.proposeAdjustReputation(evaluator2, newReputation);
    }

    function testTargetShouldBeEvaluatorToAdjustReputation() external {
        uint8 newReputation = 14;
        address nonEvaluator = makeAddr("Nonexistent");

        vm.prank(evaluator1);
        vm.expectRevert("Target address should be an evaluator");
        evaluatorGovernor.proposeAdjustReputation(nonEvaluator, newReputation);
    }

    function testAdjustReputationCreatesAProposal() external {
        uint8 newReputation = 14;

        vm.prank(evaluator1);
        evaluatorGovernor.proposeAdjustReputation(evaluator1, newReputation);

        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();
        EvaluatorGovernor.EvaluatorProposal memory proposal = evaluatorGovernor
            .getEvaluatorProposal(currentProposalId);

        assertEq(newReputation, proposal.newReputation);
    }

    function testProposeAdjustReputationEmitsEvent() external {
        uint8 newReputation = 14;

        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();

        vm.expectEmit(address(evaluatorGovernor));
        emit EvaluatorGovernor.ReputationAdjustmentProposalAdded(
            currentProposalId + 1,
            evaluator1,
            newReputation,
            block.timestamp + EVALUATOR_VOTING_PERIOD
        );

        vm.prank(evaluator1);
        evaluatorGovernor.proposeAdjustReputation(evaluator1, newReputation);
    }

    //--------------------- setRoundManager ---------------------//

    function testSetProjectRegistryRevertsIfZeroAddressGiven() external {
        vm.expectRevert("EvaluatorGovernor__ZeroAddressNotAllowed()");
        evaluatorGovernor.setProjectRegistry(address(0));
    }

    function testSetProjectRegistryRevertsIfCalledAfterDeployment() external {
        address newProjectRegistry = makeAddr("New Project Registry");
        vm.expectRevert("EvaluatorGovernor_ProjectRegistryAlreadySet()");

        evaluatorGovernor.setProjectRegistry(newProjectRegistry);
    }

    //--------------------- proposeImpactEval ---------------------//

    function testProposeImpactEvalRevertsIfNotProjectRegistry() external {
        uint256 roundId = 20;
        uint256 projectId = 199;
        uint256 votingPeriod = 2000;

        vm.expectRevert("Only Project Registry can call this function.");
        evaluatorGovernor.proposeImpactEval(roundId, projectId, votingPeriod);
    }

    function testProposeImpactEvalCreatesAProposal() external {
        uint256 roundId = 20;
        uint256 projectId = 199;
        uint256 votingPeriod = 2000;

        vm.prank(address(projectRegistry));
        evaluatorGovernor.proposeImpactEval(roundId, projectId, votingPeriod);

        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();
        EvaluatorGovernor.ImpactProposal memory proposal = evaluatorGovernor
            .getImpactProposal(currentProposalId);

        assertEq(projectId, proposal.projectId);
    }

    function testProposeImpactEvalEmitsEvent() external {
        uint256 roundId = 20;
        uint256 projectId = 199;
        uint256 votingPeriod = 2000;

        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();

        vm.expectEmit(address(evaluatorGovernor));
        emit EvaluatorGovernor.ImpactEvaluationProposalAdded(
            currentProposalId + 1,
            roundId,
            projectId,
            block.timestamp + votingPeriod
        );

        vm.prank(address(projectRegistry));
        evaluatorGovernor.proposeImpactEval(roundId, projectId, votingPeriod);
    }

    //--------------------- voteEvaluator ---------------------//
    function testOnlyEvaluatorCanVoteEvaluator() external {
        address newEvaluator = makeAddr("New evaluator");
        uint8 newReputation = 66;

        vm.prank(evaluator1);
        evaluatorGovernor.proposeAddEvaluator(newEvaluator, newReputation);

        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();
        vm.expectRevert("Should be an evaluator");

        evaluatorGovernor.voteEvaluator(currentProposalId, 1);
    }

    function testVoteEvaluatorRevertsIfProposalDoesntExist() external {
        vm.prank(evaluator1);
        vm.expectRevert("EvaluatorGovernor__ProposalDoesNotExist()");
        evaluatorGovernor.voteEvaluator(122, 1);
    }

    function testViteEvaluatorRevertsIfVotingPeriodIsOver() external {
        address newEvaluator = makeAddr("New evaluator");
        uint8 newReputation = 66;

        vm.prank(evaluator1);
        evaluatorGovernor.proposeAddEvaluator(newEvaluator, newReputation);

        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();

        vm.warp(block.timestamp + EVALUATOR_VOTING_PERIOD + 1);

        vm.expectRevert("EvaluatorGovernor__VotingPeriodOver()");
        vm.prank(evaluator1);
        evaluatorGovernor.voteEvaluator(currentProposalId, 1);
    }

    function testVoteEvaluatorRevertsIfAlreadyVoted() external {
        address newEvaluator = makeAddr("New evaluator");
        uint8 newReputation = 66;

        vm.prank(evaluator1);
        evaluatorGovernor.proposeAddEvaluator(newEvaluator, newReputation);

        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();

        vm.prank(evaluator1);
        evaluatorGovernor.voteEvaluator(currentProposalId, 1);

        vm.expectRevert("EvaluatorGovernor__AlreadyVoted()");
        vm.prank(evaluator1);
        evaluatorGovernor.voteEvaluator(currentProposalId, 1);
    }

    function testVoteAddedWhenCallingVoteEvaluator() external {
        address newEvaluator = makeAddr("New evaluator");
        uint8 newReputation = 66;

        vm.prank(evaluator1);
        evaluatorGovernor.proposeAddEvaluator(newEvaluator, newReputation);

        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();

        vm.prank(evaluator1);
        evaluatorGovernor.voteEvaluator(currentProposalId, 1);

        EvaluatorGovernor.EvaluatorProposal memory proposal = evaluatorGovernor
            .getEvaluatorProposal(currentProposalId);

        assertEq(proposal.yesVotes, 1);
    }

    function testVoteEvaluatorEmitsEvent() external {
        address newEvaluator = makeAddr("New evaluator");
        uint8 newReputation = 66;

        vm.prank(evaluator1);
        evaluatorGovernor.proposeAddEvaluator(newEvaluator, newReputation);

        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();

        vm.expectEmit(address(evaluatorGovernor));
        emit EvaluatorGovernor.VotedOnEvaluator(currentProposalId, 1);
        vm.prank(evaluator1);
        evaluatorGovernor.voteEvaluator(currentProposalId, 1);
    }

    //--------------------- voteProjectImpact ---------------------//

    function testOnlyEvaluatorCanVoteProjectImpact() external {
        uint256 roundId = 20;
        uint256 projectId = 199;
        uint256 votingPeriod = 2000;
        uint8 projectImpact = 70;

        vm.prank(address(projectRegistry));
        evaluatorGovernor.proposeImpactEval(roundId, projectId, votingPeriod);

        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();

        vm.expectRevert("Should be an evaluator");
        evaluatorGovernor.voteProjectImpact(currentProposalId, projectImpact);
    }

    function testVoteProjectImpactRevertsIfProposalDoesntExist() external {
        uint256 proposalId = 122;
        uint8 projectImpact = 70;

        vm.expectRevert("EvaluatorGovernor__ProposalDoesNotExist()");
        vm.prank(evaluator1);
        evaluatorGovernor.voteProjectImpact(proposalId, projectImpact);
    }

    function testVoteProjectImpactRevertsIfVotingPeriodOver() external {
        uint256 roundId = 20;
        uint256 projectId = 199;
        uint256 votingPeriod = 2000;
        uint8 projectImpact = 70;

        vm.prank(address(projectRegistry));
        evaluatorGovernor.proposeImpactEval(roundId, projectId, votingPeriod);

        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();

        vm.warp(votingPeriod + 1);

        vm.expectRevert("EvaluatorGovernor__VotingPeriodOver()");
        vm.prank(evaluator1);
        evaluatorGovernor.voteProjectImpact(currentProposalId, projectImpact);
    }

    function testVoteProjectImpactRevertsIfAlreadyVoted() external {
        uint256 roundId = 20;
        uint256 projectId = 199;
        uint256 votingPeriod = 2000;
        uint8 projectImpact = 70;

        vm.prank(address(projectRegistry));
        evaluatorGovernor.proposeImpactEval(roundId, projectId, votingPeriod);

        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();

        vm.prank(evaluator1);
        evaluatorGovernor.voteProjectImpact(currentProposalId, projectImpact);

        vm.expectRevert("EvaluatorGovernor__AlreadyVoted()");
        vm.prank(evaluator1);
        evaluatorGovernor.voteProjectImpact(currentProposalId, projectImpact);
    }

    function testVoteProjectImpactRevertsIfVoteOutOfRange() external {
        uint256 roundId = 20;
        uint256 projectId = 199;
        uint256 votingPeriod = 2000;
        uint8 projectImpact = 101;

        vm.prank(address(projectRegistry));
        evaluatorGovernor.proposeImpactEval(roundId, projectId, votingPeriod);

        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();

        vm.expectRevert("EvaluatorGovernor__VoteOutOfRange()");
        vm.prank(evaluator1);
        evaluatorGovernor.voteProjectImpact(currentProposalId, projectImpact);
    }

    function testVoteProjectImpactAddsAVote() external {
        uint256 roundId = 20;
        uint256 projectId = 199;
        uint256 votingPeriod = 2000;
        uint8 projectImpact = 96;
        uint8 reputation = evaluatorSbtContract.getReputation(evaluator1);

        vm.prank(address(projectRegistry));
        evaluatorGovernor.proposeImpactEval(roundId, projectId, votingPeriod);

        uint256 currentProposalId = evaluatorGovernor.getCurrentProposalId();

        vm.prank(evaluator1);
        evaluatorGovernor.voteProjectImpact(currentProposalId, projectImpact);

        EvaluatorGovernor.ImpactProposal memory proposal = evaluatorGovernor
            .getImpactProposal(currentProposalId);

        assertEq(proposal.roundId, roundId);
        assertEq(proposal.projectId, projectId);
        assertEq(proposal.endTime, votingPeriod);
        assertEq(
            proposal.sumWeighted,
            uint256(projectImpact) * uint256(reputation)
        );
        assertEq(proposal.sumWeights, reputation);
    }

    function testVoteProjectImpactEmitsEvent() external {}
}
