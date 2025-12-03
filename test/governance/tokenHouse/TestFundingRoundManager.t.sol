// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "forge-std/console.sol";
import "@test/utils/BaseTest.t.sol";
import {FundingRoundManager} from "@src/governance/tokenHouse/FundingRoundManager.sol";

contract TestFundingRoundManager is BaseTest {
    //--------------------- setProjectRegistry ---------------------//
    function testSetProjectRegistryRevertsIfAddressZero() external {
        vm.expectRevert("FundingRoundManager__AddressCannotBeZero()");
        fundingRoundManager.setProjectRegistry(address(0));
    }

    function testSetProjectRegistryCantBeCalledTwice() external {
        vm.expectRevert("FundingRoundManager__ProjectRegistryAlreadySet()");
        fundingRoundManager.setProjectRegistry(address(projectRegistry));
    }

    //--------------------- startRound ---------------------//

    function testStartRoundRevertsIfNotTimelock() external {
        uint256 roundBudget = 12 ether;
        uint256 endsAt = block.timestamp + 20000;

        vm.expectRevert("Only timelock allowed");
        fundingRoundManager.startRound(roundBudget, endsAt);
    }

    function testStartRoundRevertsIfTimeLessThanCurrentTimestamp() external {
        uint256 roundBudget = 12 ether;
        uint256 endsAt = 0;

        vm.expectRevert("FundingRoundManager__EndTimeMustBeInTheFuture()");
        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);
    }

    function testStartRoundRevertsIfBudgetZero() external {
        uint256 roundBudget = 0;
        uint256 endsAt = 2000;

        vm.expectRevert("FundingRoundManager__BudgetCannotBeZero()");
        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);
    }

    function testStartRoundRevertsIfSentValueIsIncorrect() external {
        uint256 roundBudget = 1 ether;
        uint256 endsAt = 2000;

        vm.expectRevert("FundingRoundManager__SendTheRightBudgetAmount()");
        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: 12}(roundBudget, endsAt);
    }

    function testStartRoundRevertsIfAnotherRoundOngoing() external {
        uint256 roundBudget = 1 ether;
        uint256 endsAt = 2000;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        vm.expectRevert("FundingRoundManager__AnotherRoundOngoing()");
        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);
    }

    function testStartRoundEmitsEvent() external {
        uint256 roundBudget = 1 ether;
        uint256 endsAt = 2000;

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.expectEmit(address(fundingRoundManager));
        emit FundingRoundManager.RoundStarted(
            currentRoundId + 1,
            roundBudget,
            endsAt
        );
        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);
    }

    //--------------------- endCurrentRound ---------------------//

    function testOnlyTimelockCanEndRound() external {
        vm.expectRevert("Only timelock allowed");
        fundingRoundManager.endCurrentRound();
    }

    function testEndRoundRevertsIfRoundHasntEnded() external {
        uint256 roundBudget = 1 ether;
        uint256 endsAt = 2000;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        vm.expectRevert("FundingRoundManager__RoundHasNotEnded()");
        vm.prank(address(timelock));
        fundingRoundManager.endCurrentRound();
    }

    function testEndRoundReturnsBudgetToTimelockIfNoProjectsRegistered()
        external
    {
        uint256 roundBudget = 1 ether;
        uint256 endsAt = 2000;
        uint256 initialBalanceTimelock = address(timelock).balance;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        vm.warp(endsAt + 1);

        vm.prank(address(timelock));
        fundingRoundManager.endCurrentRound();
        assertEq(address(timelock).balance, initialBalanceTimelock);
    }

    function testEndRoundChangesTimelockBalance() external {
        uint256 budget = 1 ether;
        uint256 endsAt = 2000;
        uint256 projectDeposit = projectRegistry.getProjectDepositAmount();
        string memory uri = "uri";
        uint8 impact = 50;
        uint256 timelockBalanceBefore = address(timelock).balance;

        // FundingRoundManager: Start a new round
        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: budget}(budget, endsAt);

        // ProjectRegistry: Register a new project

        uint256 projectId = projectRegistry.registerProject{
            value: projectDeposit
        }(uri);

        // EvaluatorGovernor: Vote on project impact
        uint256 roundId = fundingRoundManager.getCurrentRoundId();
        uint256 proposalId = evaluatorGovernor.getImpactProposalIdForProject(
            roundId,
            projectId
        );

        vm.prank(evaluator1);
        evaluatorGovernor.voteProjectImpact(proposalId, impact);

        vm.prank(evaluator2);
        evaluatorGovernor.voteProjectImpact(proposalId, impact - 10);

        vm.prank(evaluator3);
        evaluatorGovernor.voteProjectImpact(proposalId, impact + 40);

        vm.prank(evaluator4);
        evaluatorGovernor.voteProjectImpact(proposalId, impact + 23);

        vm.warp(endsAt + 1);

        // FundingRoundManager: EndRound (Pay to projects)
        vm.prank(address(timelock));
        fundingRoundManager.endCurrentRound();

        uint256 timelockBalanceAfter = address(timelock).balance;
        console.log("Balance timelock before:", timelockBalanceBefore);
        console.log("Balance timelock after:", timelockBalanceAfter);
        assert(timelockBalanceAfter != timelockBalanceBefore);
    }

    //--------------------- endCurrentRound ---------------------//

    function testWithdrawAllPaymentsRevertsIfNothingToPay() external {
        vm.expectRevert("FundingRoundManager__NothingToPay()");
        fundingRoundManager.withdrawAllPayments();
    }

    function testWithdrawAllPaymentsEmitsEvent() external {
        uint256 budget = 1 ether;
        uint256 endsAt = 2000;
        uint256 projectDeposit = projectRegistry.getProjectDepositAmount();
        string memory uri = "uri";
        uint8 impact = 50;
        address projectAddress = makeAddr("Project address");
        vm.deal(projectAddress, 1 ether);

        // FundingRoundManager: Start a new round
        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: budget}(budget, endsAt);

        // ProjectRegistry: Register a new project

        vm.prank(projectAddress);
        uint256 projectId = projectRegistry.registerProject{
            value: projectDeposit
        }(uri);

        // EvaluatorGovernor: Vote on project impact
        uint256 roundId = fundingRoundManager.getCurrentRoundId();
        uint256 proposalId = evaluatorGovernor.getImpactProposalIdForProject(
            roundId,
            projectId
        );

        vm.prank(evaluator1);
        evaluatorGovernor.voteProjectImpact(proposalId, impact);

        vm.prank(evaluator2);
        evaluatorGovernor.voteProjectImpact(proposalId, impact - 10);

        vm.prank(evaluator3);
        evaluatorGovernor.voteProjectImpact(proposalId, impact + 40);

        vm.prank(evaluator4);
        evaluatorGovernor.voteProjectImpact(proposalId, impact + 23);

        vm.warp(endsAt + 1);

        // FundingRoundManager: EndRound (Pay to projects)
        vm.prank(address(timelock));
        fundingRoundManager.endCurrentRound();

        uint256 payout = fundingRoundManager.getPayout(projectAddress);
        vm.expectEmit(address(fundingRoundManager));
        emit FundingRoundManager.PaymentsWithdrawn(projectAddress, payout);
        vm.prank(projectAddress);
        fundingRoundManager.withdrawAllPayments();
    }
}
