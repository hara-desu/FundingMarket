// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "forge-std/console.sol";
import "@test/utils/BaseTest.t.sol";
import {FundingMarket} from "@src/market/FundingMarket.sol";

contract TestFundingMarket is BaseTest {
    address public PROJECT = makeAddr("Project");
    uint256 public INITIAL_TOKEN_VALUE = 1e16;
    uint256 public PRECISION = 1e18;
    uint256 public endsAt = 2000;

    function getMarketAddress()
        internal
        returns (address marketAddr, uint256 projectId, uint256 currentRoundId)
    {
        uint256 roundBudget = 1 ether;
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

        address marketAddr = projectRegistry.getMarketForProject(projectId);
        return (marketAddr, projectId, currentRoundId);
    }

    //--------------------- addLiquidity ---------------------//

    function testAddLiquidityRevertsIfNotTimelock() external {
        (address marketAddress, , ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;

        vm.expectRevert();
        market.addLiquidity{value: liquidity}();
    }

    function testAddLiquidityEmitsEvent() external {
        (address marketAddress, , ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;

        vm.expectEmit(marketAddress);
        emit FundingMarket.LiquidityAdded(liquidity);
        vm.prank(address(timelock));
        market.addLiquidity{value: liquidity}();
    }

    //--------------------- removeLiquidity ---------------------//

    function testRemoveLiquidityRevertsIfNotTimelock() external {
        (address marketAddress, , ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;

        vm.prank(address(timelock));
        market.addLiquidity{value: liquidity}();

        vm.expectRevert();
        market.removeLiquidity(liquidity);
    }

    function testRemoveLiquidityRevertsIfInsufficientTokenReserve() external {
        (address marketAddress, , ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;

        vm.expectRevert();
        vm.prank(address(timelock));
        market.removeLiquidity(liquidity);
    }

    function testRemoveLiquidityEmitsEvent() external {
        (address marketAddress, , ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;

        vm.prank(address(timelock));
        market.addLiquidity{value: liquidity}();

        uint256 tokensToBurn = (liquidity * PRECISION) / INITIAL_TOKEN_VALUE;

        vm.expectEmit(marketAddress);
        emit FundingMarket.LiquidityRemoved(liquidity, tokensToBurn);
        vm.prank(address(timelock));
        market.removeLiquidity(liquidity);
    }

    //--------------------- buyTokensWithETH ---------------------//

    function testBuyTokensRevertsIfAmountZero() external {
        (address marketAddress, , ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;
        uint256 amountToBuy = 0;

        vm.prank(address(timelock));
        market.addLiquidity{value: liquidity}();

        vm.expectRevert("FundingMarket__AmountMustBeGreaterThanZero()");
        market.buyTokensWithETH(FundingMarket.Side.LONG, amountToBuy);
    }

    function testBuyTokensRevertsIfRoundAlreadyEnded() external {
        (
            address marketAddress,
            uint256 projectId,
            uint256 roundId
        ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;
        uint256 amountToBuy = 15;
        uint8 projectScore = 70;

        vm.prank(address(timelock));
        market.addLiquidity{value: liquidity}();

        uint256 proposalId = evaluatorGovernor.getImpactProposalIdForProject(
            roundId,
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

        uint256 amountToSend = market.getBuyPriceInEth(
            FundingMarket.Side.LONG,
            amountToBuy
        );

        vm.expectRevert("FundingMarket__RoundAlreadyEnded()");
        market.buyTokensWithETH{value: amountToSend}(
            FundingMarket.Side.LONG,
            amountToBuy
        );
    }

    function testBuyTokensRevertsIfMarketAlreadyFinalized() external {
        (
            address marketAddress,
            uint256 projectId,
            uint256 roundId
        ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;
        uint256 amountToBuy = 15;
        uint8 projectScore = 70;
        address user = makeAddr("User");

        vm.prank(address(timelock));
        market.addLiquidity{value: liquidity}();

        uint256 proposalId = evaluatorGovernor.getImpactProposalIdForProject(
            roundId,
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

        uint256 amountToSend = market.getBuyPriceInEth(
            FundingMarket.Side.LONG,
            amountToBuy
        );

        vm.deal(user, 14 ether);
        vm.prank(user);
        market.buyTokensWithETH{value: amountToSend}(
            FundingMarket.Side.LONG,
            amountToBuy
        );

        vm.warp(endsAt + 1);

        vm.prank(address(timelock));
        fundingRoundManager.endCurrentRound();

        vm.prank(user);
        market.redeemLong(amountToBuy);

        vm.expectRevert("FundingMarket__AlreadyFinalized()");
        market.buyTokensWithETH{value: amountToSend}(
            FundingMarket.Side.LONG,
            amountToBuy
        );
    }

    function testBuyTokensRevertsIfNotExactETHAmount() external {}
}
