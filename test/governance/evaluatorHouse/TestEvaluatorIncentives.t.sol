// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "forge-std/console.sol";
import "@test/utils/BaseTest.t.sol";

contract TestEvaluatorIncentives is BaseTest {
    //--------------------- fundRound ---------------------//
    function testFundRoundRevertsIfNotTimelock() external {
        uint256 fundingAmount = 5 ether;

        vm.expectRevert("Only Timelock can call this function");
        evaluatorIncentives.fundRound{value: fundingAmount}();
    }

    function testFundRoundRevertsIfRoundDoesntExist() external {
        uint256 fundingAmount = 5 ether;

        vm.expectRevert("EvaluatorIncentives__RoundDoesNotExist()");
        vm.prank(address(timelock));
        evaluatorIncentives.fundRound{value: fundingAmount}();
    }

    function testFundRoundRevertsIfRoundEnded() external {
        uint256 fundingAmount = 5 ether;
        uint256 roundBudget = 10 ether;
        uint256 endsAt = 2000;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        vm.warp(endsAt + 1);

        vm.expectRevert("EvaluatorIncentives__RoundEnded()");
        vm.prank(address(timelock));
        evaluatorIncentives.fundRound{value: fundingAmount}();
    }

    function testFundRoundRevertsIfRoundAlreadyFunded() external {
        uint256 fundingAmount = 5 ether;
        uint256 roundBudget = 10 ether;
        uint256 endsAt = 2000;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        vm.prank(address(timelock));
        evaluatorIncentives.fundRound{value: fundingAmount}();

        vm.expectRevert("EvaluatorIncentives__RoundAlreadyFunded()");
        vm.prank(address(timelock));
        evaluatorIncentives.fundRound{value: fundingAmount}();
    }

    function testFundRoundEmitsEvent() external {
        uint256 fundingAmount = 5 ether;
        uint256 roundBudget = 10 ether;
        uint256 endsAt = 2000;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.expectEmit(address(evaluatorIncentives));
        emit EvaluatorIncentives.RoundFunded(currentRoundId, fundingAmount);
        vm.prank(address(timelock));
        evaluatorIncentives.fundRound{value: fundingAmount}();
    }

    //--------------------- registerForRoundPayout ---------------------//

    function testRegisterForRoundPayoutRevertsIfNotEvaluator() external {
        vm.expectRevert("Only evaluators allowed");
        evaluatorIncentives.registerForRoundPayout(1);
    }

    function testRegisterForRoundPayoutRevertsIfRoundEnded() external {
        uint256 roundBudget = 10 ether;
        uint256 endsAt = 2000;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.warp(endsAt + 1);
        vm.expectRevert("EvaluatorIncentives__RoundEnded()");
        vm.prank(evaluator1);
        evaluatorIncentives.registerForRoundPayout(currentRoundId);
    }

    function testRegisterForRoundPayoutRevertsIfRoundNotFunded() external {
        uint256 roundBudget = 10 ether;
        uint256 endsAt = 2000;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.expectRevert("EvaluatorIncentives__RoundNotFunded()");
        vm.prank(evaluator1);
        evaluatorIncentives.registerForRoundPayout(currentRoundId);
    }

    function testRegisterForRoundPayourRevertsIfAlreadyRegistered() external {
        uint256 roundBudget = 10 ether;
        uint256 endsAt = 2000;
        uint256 fundingAmount = 1 ether;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.prank(address(timelock));
        evaluatorIncentives.fundRound{value: fundingAmount}();

        vm.prank(evaluator1);
        evaluatorIncentives.registerForRoundPayout(currentRoundId);

        vm.expectRevert("EvaluatorIncentives__AlreadyRegistered()");
        vm.prank(evaluator1);
        evaluatorIncentives.registerForRoundPayout(currentRoundId);
    }

    function testRegisterForRoundPayoutEmitsEvent() external {
        uint256 roundBudget = 10 ether;
        uint256 endsAt = 2000;
        uint256 fundingAmount = 1 ether;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.prank(address(timelock));
        evaluatorIncentives.fundRound{value: fundingAmount}();

        vm.expectEmit(address(evaluatorIncentives));
        emit EvaluatorIncentives.RegisteredForPayout(
            currentRoundId,
            evaluator1
        );
        vm.prank(evaluator1);
        evaluatorIncentives.registerForRoundPayout(currentRoundId);
    }

    //--------------------- withdrawReward ---------------------//

    function testWithdrawRewardRevertsIfNotEvaluator() external {
        vm.expectRevert("Only evaluators allowed");
        evaluatorIncentives.withdrawReward(122);
    }

    function testWithdrawRewardRevertsIfRoundNotEnded() external {
        uint256 roundBudget = 10 ether;
        uint256 endsAt = 2000;
        uint256 fundingAmount = 1 ether;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.prank(address(timelock));
        evaluatorIncentives.fundRound{value: fundingAmount}();

        vm.expectRevert("EvaluatorIncentives__RoundNotEndedYet()");
        vm.prank(evaluator1);
        evaluatorIncentives.withdrawReward(currentRoundId);
    }

    function testWithdrawRewardIfRoundNotFunded() external {
        uint256 roundBudget = 10 ether;
        uint256 endsAt = 2000;
        uint256 fundingAmount = 1 ether;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.warp(endsAt + 1);

        vm.prank(address(timelock));
        fundingRoundManager.endCurrentRound();

        vm.expectRevert("EvaluatorIncentives__RoundNotFunded()");
        vm.prank(evaluator1);
        evaluatorIncentives.withdrawReward(currentRoundId);
    }

    function testWithdrawRewardRevertsIfNotRegistered() external {
        uint256 roundBudget = 10 ether;
        uint256 endsAt = 2000;
        uint256 fundingAmount = 1 ether;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.prank(address(timelock));
        evaluatorIncentives.fundRound{value: fundingAmount}();

        vm.warp(endsAt + 1);

        vm.prank(address(timelock));
        fundingRoundManager.endCurrentRound();

        vm.expectRevert("EvaluatorIncentives__NobodyHasRegisteredForPayout()");
        vm.prank(evaluator1);
        evaluatorIncentives.withdrawReward(currentRoundId);
    }

    function testWithdrawRewardRevertsIfDidntRegisterForPayout() external {
        uint256 roundBudget = 10 ether;
        uint256 endsAt = 2000;
        uint256 fundingAmount = 1 ether;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.prank(address(timelock));
        evaluatorIncentives.fundRound{value: fundingAmount}();

        vm.prank(evaluator2);
        evaluatorIncentives.registerForRoundPayout(currentRoundId);

        vm.warp(endsAt + 1);

        vm.prank(address(timelock));
        fundingRoundManager.endCurrentRound();

        vm.expectRevert("EvaluatorIncentives__DidNotRegisterForPayout()");
        vm.prank(evaluator1);
        evaluatorIncentives.withdrawReward(currentRoundId);
    }

    function testWithdrawRewardRevertsIfAlreadyClaimed() external {
        uint256 roundBudget = 10 ether;
        uint256 endsAt = 2000;
        uint256 fundingAmount = 1 ether;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.prank(address(timelock));
        evaluatorIncentives.fundRound{value: fundingAmount}();

        vm.prank(evaluator1);
        evaluatorIncentives.registerForRoundPayout(currentRoundId);

        vm.warp(endsAt + 1);

        vm.prank(address(timelock));
        fundingRoundManager.endCurrentRound();

        vm.prank(evaluator1);
        evaluatorIncentives.withdrawReward(currentRoundId);

        vm.expectRevert("EvaluatorIncentives__PayoutAlreadyCalimed()");
        vm.prank(evaluator1);
        evaluatorIncentives.withdrawReward(currentRoundId);
    }

    function testWithdrawRewardEmitsEvent() external {
        uint256 roundBudget = 10 ether;
        uint256 endsAt = 2000;
        uint256 fundingAmount = 1 ether;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.prank(address(timelock));
        evaluatorIncentives.fundRound{value: fundingAmount}();

        vm.prank(evaluator1);
        evaluatorIncentives.registerForRoundPayout(currentRoundId);

        vm.warp(endsAt + 1);

        vm.prank(address(timelock));
        fundingRoundManager.endCurrentRound();

        vm.expectEmit(address(evaluatorIncentives));
        emit EvaluatorIncentives.RewardWithdrawn(
            currentRoundId,
            evaluator1,
            fundingAmount
        );
        vm.prank(evaluator1);
        evaluatorIncentives.withdrawReward(currentRoundId);
    }
}
