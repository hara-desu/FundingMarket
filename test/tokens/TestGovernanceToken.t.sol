// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "forge-std/console.sol";
import "@test/utils/BaseTest.t.sol";

contract TestGovernanceToken is BaseTest {
    //--------------------- mint ---------------------//

    function testMintingToEvaluatorFails() external {
        vm.expectRevert("FunDAOToken__EvaluatorCannotReceiveTokens()");
        vm.prank(address(timelock));
        governanceToken.mint(evaluator1, 1000e18);
    }

    function testMintFailsIfNotTimelock() external {
        address user = makeAddr("USER");

        vm.expectRevert(
            "OwnableUnauthorizedAccount(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496)"
        );
        governanceToken.mint(user, 1000e18);
    }

    function testMintToNonEvaluatorSucceeds() public {
        address nonEvaluator = makeAddr("Non evaluator");

        uint256 amount = 50e18;
        uint256 prevBalance = governanceToken.balanceOf(nonEvaluator);
        uint256 prevSupply = governanceToken.totalSupply();

        vm.prank(address(timelock));
        governanceToken.mint(nonEvaluator, amount);

        assertEq(
            governanceToken.balanceOf(nonEvaluator),
            prevBalance + amount,
            "minted balance mismatch"
        );
        assertEq(
            governanceToken.totalSupply(),
            prevSupply + amount,
            "totalSupply should increase by minted amount"
        );
    }

    //--------------------- delegate ---------------------//

    function testDelegationToEvaluatorFails() external {
        address user = makeAddr("USER");

        vm.prank(address(timelock));
        governanceToken.mint(user, 1000e18);

        vm.expectRevert("FunDAOToken__EvaluatorsCannotReceiveDelegation()");
        vm.prank(user);
        governanceToken.delegate(evaluator1);
    }

    //--------------------- transfer ---------------------//

    function testTransferNotAllowedToEvaluator() external {
        vm.expectRevert("FunDAOToken__EvaluatorCannotReceiveTokens()");
        vm.prank(address(timelock));
        governanceToken.transfer(evaluator1, 100e18);
    }

    function testTransferToNonEvaluatorSucceeds() public {
        address nonEvaluator = makeAddr("NonEvaluator");
        address user = makeAddr("User");
        uint256 amount = 5e18;

        vm.prank(address(timelock));
        governanceToken.mint(user, amount);

        uint256 prevFrom = governanceToken.balanceOf(user);
        uint256 prevTo = governanceToken.balanceOf(nonEvaluator);

        vm.prank(user);
        governanceToken.transfer(nonEvaluator, amount);

        assertEq(
            governanceToken.balanceOf(user),
            prevFrom - amount,
            "sender balance mismatch"
        );
        assertEq(
            governanceToken.balanceOf(nonEvaluator),
            prevTo + amount,
            "receiver balance mismatch"
        );
    }

    //--------------------- transferFrom ---------------------//

    function testTransferFromToEvaluatorReverts() public {
        uint256 amount = 1e18;
        address user = makeAddr("User");
        address nonEvaluator = makeAddr("NonEvaluator");

        vm.prank(address(timelock));
        governanceToken.mint(user, amount);

        vm.prank(user);
        governanceToken.approve(nonEvaluator, amount);

        vm.expectRevert(
            FunDAOToken.FunDAOToken__EvaluatorCannotReceiveTokens.selector
        );
        vm.prank(nonEvaluator);
        governanceToken.transferFrom(user, evaluator1, amount);
    }
}
