// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "forge-std/console.sol";
import "@test/utils/BaseTest.t.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract TestTokenHouseGovernor is BaseTest {
    address voter = makeAddr("VOTER");

    function setUp() public override {
        super.setUp();

        vm.prank(address(timelock));
        governanceToken.delegate(address(timelock));

        vm.prank(address(timelock));
        governanceToken.mint(voter, 100e18);

        vm.prank(voter);
        governanceToken.delegate(voter);
    }

    function testConstructorParamsAreSet() public {
        assertEq(tokenHouseGovernor.name(), "TokenHouse");

        assertEq(
            tokenHouseGovernor.votingDelay(),
            7200,
            "votingDelay mismatch"
        );
        assertEq(
            tokenHouseGovernor.votingPeriod(),
            21600,
            "votingPeriod mismatch"
        );
        assertEq(
            tokenHouseGovernor.proposalThreshold(),
            0,
            "proposalThreshold should be zero"
        );

        assertEq(
            address(tokenHouseGovernor.token()),
            address(governanceToken),
            "governor token mismatch"
        );
        assertEq(
            address(tokenHouseGovernor.timelock()),
            address(timelock),
            "governor timelock mismatch"
        );
    }

    function testQuorumIsFourPercentOfTotalSupply() public {
        uint256 totalSupply = governanceToken.totalSupply();
        uint256 expectedQuorum = (totalSupply * 4) / 100;

        // Need to use a *past* block for GovernorVotesQuorumFraction
        vm.roll(10);
        uint256 blockNumber = block.number - 1;

        uint256 q = tokenHouseGovernor.quorum(blockNumber);
        assertEq(q, expectedQuorum, "quorum should be 4% of total supply");
    }

    function testNonEvaluatorHasNormalVotes() public {
        // Need to move one block so checkpoints are in the past.
        vm.roll(block.number + 1);
        uint256 pastBlock = block.number - 1;

        // Underlying token voting power
        uint256 tokenVotes = governanceToken.getPastVotes(voter, pastBlock);
        assertGt(tokenVotes, 0, "underlying token should show votes for voter");

        // Governor should see the same.
        uint256 govVotes = tokenHouseGovernor.getVotes(voter, pastBlock);
        assertEq(govVotes, tokenVotes, "governor voting power mismatch");
    }
}
