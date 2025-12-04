// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "forge-std/console.sol";
import "@test/utils/BaseTest.t.sol";

contract TestProjectRegistry is BaseTest {
    //--------------------- registerProject ---------------------//
    function testRegisterProjectRevertsIfCalledByEvaluator() external {
        string memory uri = "uri";

        vm.expectRevert("Evaluators are restricted from registering projects");
        vm.prank(evaluator1);
        projectRegistry.registerProject(uri);
    }

    function testRegisterProjectRevertsIfNoMetadataProvided() external {
        string memory uri = "";

        vm.expectRevert("ProjectRegistry__InvalidMetadataUri()");
        projectRegistry.registerProject(uri);
    }

    function testRegisterProjectRevertsIfInvalidDepositAmount() external {
        string memory uri = "uri";
        uint256 depositAmount = 123;

        vm.expectRevert("ProjectRegistry__InvalidDepositAmount()");
        projectRegistry.registerProject{value: depositAmount}(uri);
    }

    function testRegisterProjectRevertsIfNoActiveRound() external {
        string memory uri = "uri";
        uint256 depositAmount = projectRegistry.getProjectDepositAmount();

        vm.expectRevert("ProjectRegistry__InvalidRoundId()");
        projectRegistry.registerProject{value: depositAmount}(uri);
    }

    function testRegisterProjectEmitsEvent() external {
        string memory uri = "uri";
        uint256 depositAmount = projectRegistry.getProjectDepositAmount();
        uint256 roundBudget = 10 ether;
        uint256 endsAt = 2000;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();
        uint256 projectId = projectRegistry.getProjectCount();

        vm.expectEmit(address(projectRegistry));
        emit ProjectRegistry.ProjectRegisteredAndMarketCreated(
            currentRoundId,
            projectId + 1
        );
        projectRegistry.registerProject{value: depositAmount}(uri);
    }

    //--------------------- withdrawAllDepositForRound ---------------------//

    function testWithdrawDepositRevertsIfNoOngoingRound() external {
        vm.expectRevert("ProjectRegistry__InvalidRoundId()");
        projectRegistry.withdrawAllDepositForRound(0);
    }

    function testWithdrawDepositRevertsIfRoundOngoing() external {
        uint256 roundBudget = 1 ether;
        uint256 endsAt = 2000;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.expectRevert("ProjectRegistry__RoundOngoing()");
        projectRegistry.withdrawAllDepositForRound(currentRoundId);
    }

    function testWithdrawDepositRevertsIfNoDepositFound() external {
        uint256 roundBudget = 1 ether;
        uint256 endsAt = 2000;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.warp(endsAt + 1);

        vm.prank(address(timelock));
        fundingRoundManager.endCurrentRound();

        vm.expectRevert("ProjectRegistry__NoDepositFound()");
        vm.prank(evaluator1);
        projectRegistry.withdrawAllDepositForRound(currentRoundId);
    }

    function testWithdrawDepositRevertsIfNotEnoughBalance() external {
        uint256 roundBudget = 1 ether;
        uint256 endsAt = 2000;
        string memory uri = "uri";
        address project = makeAddr("Project");
        uint8 projectScore = 80;
        uint256 deposit = projectRegistry.getProjectDepositAmount();

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.deal(project, 1 ether);
        vm.prank(project);
        uint256 projectId = projectRegistry.registerProject{value: deposit}(
            uri
        );

        uint256 dep = projectRegistry.getDepositForRound(
            project,
            currentRoundId
        );
        console.log("test: deposit stored:", dep);

        uint256 proposalId = evaluatorGovernor.getImpactProposalIdForProject(
            currentRoundId,
            projectId
        );

        vm.prank(evaluator1);
        evaluatorGovernor.voteProjectImpact(proposalId, projectScore);

        vm.prank(evaluator2);
        evaluatorGovernor.voteProjectImpact(proposalId, projectScore);

        vm.prank(evaluator3);
        evaluatorGovernor.voteProjectImpact(proposalId, projectScore);

        vm.prank(evaluator4);
        evaluatorGovernor.voteProjectImpact(proposalId, projectScore);

        vm.prank(evaluator5);
        evaluatorGovernor.voteProjectImpact(proposalId, projectScore);

        vm.warp(endsAt + 1);

        vm.prank(address(timelock));
        fundingRoundManager.endCurrentRound();

        vm.deal(address(projectRegistry), 0);

        vm.expectRevert("ProjectRegistry__NotEnoughBalance()");
        vm.prank(project);
        projectRegistry.withdrawAllDepositForRound(currentRoundId);
    }

    function testiWithdrawDepositEmitsEvent() external {
        uint256 roundBudget = 1 ether;
        uint256 endsAt = 2000;
        string memory uri = "uri";
        address project = makeAddr("Project");
        uint8 projectScore = 80;
        uint256 deposit = projectRegistry.getProjectDepositAmount();

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.deal(project, 1 ether);
        vm.prank(project);
        uint256 projectId = projectRegistry.registerProject{value: deposit}(
            uri
        );

        uint256 proposalId = evaluatorGovernor.getImpactProposalIdForProject(
            currentRoundId,
            projectId
        );

        vm.prank(evaluator1);
        evaluatorGovernor.voteProjectImpact(proposalId, projectScore);

        vm.prank(evaluator2);
        evaluatorGovernor.voteProjectImpact(proposalId, projectScore);

        vm.prank(evaluator3);
        evaluatorGovernor.voteProjectImpact(proposalId, projectScore);

        vm.prank(evaluator4);
        evaluatorGovernor.voteProjectImpact(proposalId, projectScore);

        vm.prank(evaluator5);
        evaluatorGovernor.voteProjectImpact(proposalId, projectScore);

        vm.warp(endsAt + 1);

        vm.prank(address(timelock));
        fundingRoundManager.endCurrentRound();

        vm.expectEmit(address(projectRegistry));
        emit ProjectRegistry.DepositWithdrawn(currentRoundId, project, deposit);
        vm.prank(project);
        projectRegistry.withdrawAllDepositForRound(currentRoundId);
    }

    //--------------------- editMetadataUri ---------------------//

    function testEditMetadataUriRevertsIfNotProjectOwner() external {
        uint256 roundBudget = 1 ether;
        uint256 endsAt = 2000;
        string memory uri = "uri";
        address project = makeAddr("Project");
        uint256 deposit = projectRegistry.getProjectDepositAmount();

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.deal(project, 1 ether);
        vm.prank(project);
        uint256 projectId = projectRegistry.registerProject{value: deposit}(
            uri
        );

        vm.expectRevert("Not the project's owner");
        projectRegistry.editMetadataUri(projectId, uri);
    }

    function testEditMetadataUriRevertsIfInvallidMetadataUri() external {
        uint256 roundBudget = 1 ether;
        uint256 endsAt = 2000;
        string memory uri = "uri";
        address project = makeAddr("Project");
        uint256 deposit = projectRegistry.getProjectDepositAmount();

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.deal(project, 1 ether);
        vm.prank(project);
        uint256 projectId = projectRegistry.registerProject{value: deposit}(
            uri
        );

        vm.expectRevert("ProjectRegistry__InvalidMetadataUri()");
        vm.prank(project);
        projectRegistry.editMetadataUri(projectId, "");
    }

    function testEditMetadataEmitsEvent() external {
        uint256 roundBudget = 1 ether;
        uint256 endsAt = 2000;
        string memory uri = "uri";
        address project = makeAddr("Project");
        uint256 deposit = projectRegistry.getProjectDepositAmount();

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.deal(project, 1 ether);
        vm.prank(project);
        uint256 projectId = projectRegistry.registerProject{value: deposit}(
            uri
        );

        vm.expectEmit(address(projectRegistry));
        emit ProjectRegistry.MetadataEdited(projectId, uri);
        vm.prank(project);
        projectRegistry.editMetadataUri(projectId, uri);
    }
}
