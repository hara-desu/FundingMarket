// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "forge-std/console.sol";
import "@test/utils/BaseTest.t.sol";
import {EvaluatorGovernor} from "@src/governance/evaluatorHouse/EvaluatorGovernor.sol";

contract TestEvaluatorSBT is BaseTest {
    uint256 public constant VOTING_PERIOD = 3 days;

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
            block.timestamp + VOTING_PERIOD
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
            block.timestamp + VOTING_PERIOD
        );

        vm.prank(evaluator1);
        evaluatorGovernor.proposeRemoveEvaluator(evaluator2);
    }

    //--------------------- proposeAdjustReputation ---------------------//
}
