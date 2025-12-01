// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "forge-std/console.sol";
import "@test/utils/BaseTest.t.sol";
import {EvaluatorSBT} from "@src/tokens/EvaluatorSBT.sol";

contract TestEvaluatorSBT is BaseTest {
    //--------------------- Constructor ---------------------//

    function testInitialEvaluatorsSetCorrectly() public {
        bool isEvaluator1 = evaluatorSbtContract.isEvaluator(evaluator1);
        bool isEvaluator2 = evaluatorSbtContract.isEvaluator(evaluator2);
        bool isEvaluator3 = evaluatorSbtContract.isEvaluator(evaluator3);
        bool isEvaluator4 = evaluatorSbtContract.isEvaluator(evaluator4);
        bool isEvaluator5 = evaluatorSbtContract.isEvaluator(evaluator5);

        assertEq(isEvaluator1, true);
        assertEq(isEvaluator2, true);
        assertEq(isEvaluator3, true);
        assertEq(isEvaluator4, true);
        assertEq(isEvaluator5, true);
    }

    function testInitialReputationsSetCorrectly() public {
        uint8 rep1 = evaluatorSbtContract.getReputation(evaluator1);
        uint8 rep2 = evaluatorSbtContract.getReputation(evaluator2);
        uint8 rep3 = evaluatorSbtContract.getReputation(evaluator3);
        uint8 rep4 = evaluatorSbtContract.getReputation(evaluator4);
        uint8 rep5 = evaluatorSbtContract.getReputation(evaluator5);

        assertEq(rep1, reputation1);
        assertEq(rep2, reputation2);
        assertEq(rep3, reputation3);
        assertEq(rep4, reputation4);
        assertEq(rep5, reputation5);
    }

    function testEvaluatorGovernorSetCorrectly() public {
        address governor = evaluatorSbtContract.getEvaluatorGovernor();
        assert(governor == address(evaluatorGovernor));
    }

    //--------------------- mintEvaluator ---------------------//

    function testEvaluatorGovernorCanMintEvaluatorSbt() public {
        address newEvaluator = makeAddr("New evaluator");
        uint8 rep = 13;

        vm.prank(address(evaluatorGovernor));
        evaluatorSbtContract.mintEvaluator(newEvaluator, rep);

        bool newEvaluatorIsEvaluator = evaluatorSbtContract.isEvaluator(
            newEvaluator
        );
        assertEq(newEvaluatorIsEvaluator, true);
    }

    function testNonEvaluatorGovernorCantMintEvaluatorSbt() public {
        address newEvaluator = makeAddr("New evaluator");
        uint8 rep = 13;

        vm.expectRevert("Not the Governor contract");
        evaluatorSbtContract.mintEvaluator(newEvaluator, rep);
    }

    function testMintFunctionEmitsEvent() public {
        address newEvaluator = makeAddr("New evaluator");
        uint8 rep = 13;

        vm.expectEmit(address(evaluatorSbtContract));
        emit EvaluatorSBT.EvaluatorReputationUpdated(newEvaluator, rep);
        emit EvaluatorSBT.EvaluatorMinted(
            newEvaluator,
            evaluatorSbtContract.getCurrentTokenId(),
            rep
        );

        vm.prank(address(evaluatorGovernor));
        evaluatorSbtContract.mintEvaluator(newEvaluator, rep);
    }

    //--------------------- burnEvaluator ---------------------//

    function testEvaluatorGovernorCanBurnEvaluator() public {
        vm.prank(address(evaluatorGovernor));
        evaluatorSbtContract.burnEvaluator(evaluator5);

        bool isEvaluator = evaluatorSbtContract.isEvaluator(evaluator5);

        assertEq(isEvaluator, false);
    }

    function testNonEvaluatorGovernorCantBurnEvaluator() public {
        vm.expectRevert("Not the Governor contract");
        evaluatorSbtContract.burnEvaluator(evaluator5);
    }

    function testBurnEvaluatorEmitsEvent() public {
        vm.expectEmit(address(evaluatorSbtContract));
        emit EvaluatorSBT.EvaluatorBurned(
            evaluator5,
            evaluatorSbtContract.getEvaluatorTokenId(evaluator5)
        );

        vm.prank(address(evaluatorGovernor));
        evaluatorSbtContract.burnEvaluator(evaluator5);
    }

    //--------------------- adjustReputation ---------------------//

    function testEvaluatorGovernorCanAdjustReputation() public {
        uint8 newReputation = 95;

        vm.prank(address(evaluatorGovernor));
        evaluatorSbtContract.adjustReputation(evaluator1, newReputation);

        uint8 adjustedReputation = evaluatorSbtContract.getReputation(
            evaluator1
        );

        assertEq(newReputation, adjustedReputation);
    }

    function testNonEvaluatorGovernorCantAdjustReputation() public {
        uint8 newReputation = 95;

        vm.expectRevert("Not the Governor contract");
        evaluatorSbtContract.adjustReputation(evaluator1, newReputation);
    }

    function testAdjustReputationEmitsEvent() public {
        uint8 newReputation = 95;

        vm.expectEmit(address(evaluatorSbtContract));
        emit EvaluatorSBT.EvaluatorReputationUpdated(evaluator1, newReputation);

        vm.prank(address(evaluatorGovernor));
        evaluatorSbtContract.adjustReputation(evaluator1, newReputation);
    }

    //--------------------- quitEvaluator ---------------------//

    function testQuitEvaluator() public {
        vm.prank(evaluator2);
        evaluatorSbtContract.quitEvaluator();

        bool isEvaluator = evaluatorSbtContract.isEvaluator(evaluator2);
        assertEq(isEvaluator, false);
    }

    function testOnlyEvaluatorCanQuit() public {
        vm.expectRevert("EvaluatorSBT__NotEvaluator()");
        evaluatorSbtContract.quitEvaluator();
    }

    function testQuitEvaluatorEmitsEvent() public {
        vm.expectEmit(address(evaluatorSbtContract));
        emit EvaluatorSBT.EvaluatorQuit(
            evaluator2,
            evaluatorSbtContract.getEvaluatorTokenId(evaluator2)
        );

        vm.prank(evaluator2);
        evaluatorSbtContract.quitEvaluator();
    }
}
