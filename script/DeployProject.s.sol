// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console2} from "forge-std/Script.sol";

import {EvaluatorGovernor} from "@src/governance/evaluatorHouse/EvaluatorGovernor.sol";
import {FunDaoTimelock} from "@src/governance/tokenHouse/Timelock.sol";
import {FunDAOToken} from "@src/tokens/GovernanceToken.sol";
import {TokenHouseGovernor} from "@src/governance/tokenHouse/TokenHouseGovernor.sol";
import {FundingRoundManager} from "@src/governance/tokenHouse/FundingRoundManager.sol";
import {ProjectRegistry} from "@src/governance/tokenHouse/ProjectRegistry.sol";
import {EvaluatorIncentives} from "@src/governance/evaluatorHouse/EvaluatorIncentives.sol";

import {IEvaluatorSBT} from "@src/Interfaces.sol";

contract DeployProjectLocal is Script {
    EvaluatorGovernor public evaluatorGovernor;
    FunDaoTimelock public timelock;
    FunDAOToken public governanceToken;
    TokenHouseGovernor public tokenHouseGovernor;
    FundingRoundManager public fundingRoundManager;
    ProjectRegistry public projectRegistry;
    EvaluatorIncentives public evaluatorIncentives;

    address[] public initialEvaluators = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8
    ];
    uint8[] public initialReputations = [23, 75];
    uint256 public MIN_DELAY = 1 days;
    address[] public proposers;
    address[] public executors = [address(0)];

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        evaluatorGovernor = new EvaluatorGovernor(
            initialEvaluators,
            initialReputations
        );
        address evaluatorSbt = evaluatorGovernor.getEvaluatorSbt();
        timelock = new FunDaoTimelock(MIN_DELAY, proposers, executors);
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
        evaluatorGovernor.setProjectRegistry(address(projectRegistry));

        evaluatorIncentives = new EvaluatorIncentives(
            address(timelock),
            evaluatorSbt,
            address(fundingRoundManager)
        );

        vm.stopBroadcast();
    }
}

contract DeployForestOchainSepolia is Script {
    EvaluatorGovernor public evaluatorGovernor;
    FunDaoTimelock public timelock;
    FunDAOToken public governanceToken;
    TokenHouseGovernor public tokenHouseGovernor;
    FundingRoundManager public fundingRoundManager;
    ProjectRegistry public projectRegistry;
    EvaluatorIncentives public evaluatorIncentives;

    address[] public initialEvaluators = [
        0x803752055A2499E7F2e25F90937c89e685dc01db
    ];
    uint8[] public initialReputations = [75];
    uint256 public MIN_DELAY = 1 days;
    address[] public proposers;
    address[] public executors = [address(0)];

    function run() public {
        require(
            block.chainid == 11155111,
            "DeployGovernanceSepolia: wrong network (not Sepolia)"
        );

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast();
        evaluatorGovernor = new EvaluatorGovernor(
            initialEvaluators,
            initialReputations
        );
        address evaluatorSbt = evaluatorGovernor.getEvaluatorSbt();
        timelock = new FunDaoTimelock(MIN_DELAY, proposers, executors);
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

        vm.stopBroadcast();
    }
}
