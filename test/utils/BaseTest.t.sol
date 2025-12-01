// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {EvaluatorGovernor} from "@src/governance/evaluatorHouse/EvaluatorGovernor.sol";
import {FunDaoTimelock} from "@src/governance/tokenHouse/Timelock.sol";
import {FunDAOToken} from "@src/tokens/GovernanceToken.sol";
import {TokenHouseGovernor} from "@src/governance/tokenHouse/TokenHouseGovernor.sol";
import {FundingRoundManager} from "@src/governance/tokenHouse/FundingRoundManager.sol";
import {ProjectRegistry} from "@src/governance/tokenHouse/ProjectRegistry.sol";
import {EvaluatorIncentives} from "@src/governance/evaluatorHouse/EvaluatorIncentives.sol";
import {EvaluatorSBT} from "@src/tokens/EvaluatorSBT.sol";

import {IEvaluatorSBT} from "@src/Interfaces.sol";

contract BaseTest is Test {
    EvaluatorGovernor public evaluatorGovernor;
    FunDaoTimelock public timelock;
    FunDAOToken public governanceToken;
    TokenHouseGovernor public tokenHouseGovernor;
    FundingRoundManager public fundingRoundManager;
    ProjectRegistry public projectRegistry;
    EvaluatorIncentives public evaluatorIncentives;
    EvaluatorSBT public evaluatorSbtContract;

    address[] public initialEvaluators;
    uint8[] public initialReputations;
    uint256 public minDelay;
    address[] public proposers;
    address[] public executors;
    address public evaluator1;
    address public evaluator2;
    address public evaluator3;
    address public evaluator4;
    address public evaluator5;

    uint8 public reputation1;
    uint8 public reputation2;
    uint8 public reputation3;
    uint8 public reputation4;
    uint8 public reputation5;

    function setUp() public virtual {
        evaluator1 = makeAddr("Evaluator 1");
        evaluator2 = makeAddr("Evaluator 2");
        evaluator3 = makeAddr("Evaluator 3");
        evaluator4 = makeAddr("Evaluator 4");
        evaluator5 = makeAddr("Evaluator 5");

        reputation1 = 23;
        reputation2 = 75;
        reputation3 = 70;
        reputation4 = 97;
        reputation5 = 12;

        initialEvaluators.push(evaluator1);
        initialEvaluators.push(evaluator2);
        initialEvaluators.push(evaluator3);
        initialEvaluators.push(evaluator4);
        initialEvaluators.push(evaluator5);

        initialReputations.push(reputation1);
        initialReputations.push(reputation2);
        initialReputations.push(reputation3);
        initialReputations.push(reputation4);
        initialReputations.push(reputation5);

        minDelay = 17;

        executors.push(address(0));

        evaluatorGovernor = new EvaluatorGovernor(
            initialEvaluators,
            initialReputations
        );
        address evaluatorSbt = evaluatorGovernor.getEvaluatorSbt();
        evaluatorSbtContract = evaluatorGovernor.getEvaluatorSbtContract();
        timelock = new FunDaoTimelock(minDelay, proposers, executors);
        governanceToken = new FunDAOToken(
            address(timelock),
            IEvaluatorSBT(evaluatorSbt)
        );
        tokenHouseGovernor = new TokenHouseGovernor(
            governanceToken,
            timelock,
            evaluatorSbt
        );

        timelock.grantRole(
            timelock.PROPOSER_ROLE(),
            address(tokenHouseGovernor)
        );

        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), msg.sender);

        fundingRoundManager = new FundingRoundManager(
            address(timelock),
            address(evaluatorGovernor)
        );

        projectRegistry = new ProjectRegistry(
            address(fundingRoundManager),
            evaluatorSbt,
            address(evaluatorGovernor),
            address(timelock)
        );

        fundingRoundManager.setProjectRegistry(address(projectRegistry));

        evaluatorIncentives = new EvaluatorIncentives(
            address(timelock),
            evaluatorSbt,
            address(fundingRoundManager)
        );
    }
}
