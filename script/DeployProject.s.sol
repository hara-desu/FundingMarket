// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console2} from "forge-std/Script.sol";

import {EvaluatorSBT} from "@src/tokens/EvaluatorSBT.sol";

import {EvaluatorGovernor} from "@src/evaluatorHouse/EvaluatorGovernor.sol";
import {EvaluatorIncentives} from "@src/evaluatorHouse/EvaluatorIncentives.sol";
import {FundingRoundManager} from "@src/tokenHouse/FundingRoundManager.sol";
import {ProjectRegistry} from "@src/tokenHouse/ProjectRegistry.sol";
import {Timelock} from "@src/tokenHouse/Timelock.sol";
import {TokenHouseGovernor} from "@src/tokenHouse/TokenHouseGovernor.sol";
import {FundingMarket} from "@src/market/FundingMarket.sol";
import {FundingMarketToken} from "@src/tokens/FundingMarketToken.sol";
import {GovernanceToken} from "@src/tokens/GovernanceToken.sol";

contract DeployProjectLocal is Script {
    EvaluatorSBT public evaluatorSbt;

    address[] public initialEvaluators = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8
    ];
    uint8[] public initialReputations = [23, 75];

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy FundingRoundManager inside EvaluatorGovernor
        // evaluatorSbt = new EvaluatorGovernor(initialEvaluators, initialReputations, );
        vm.stopBroadcast();
    }
}
