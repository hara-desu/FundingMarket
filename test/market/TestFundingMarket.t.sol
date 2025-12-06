// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "forge-std/console.sol";
import "@test/utils/BaseTest.t.sol";
import "@src/market/FundingMarket.sol";

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
        uint256 initialLiquidity = 1 ether;

        vm.prank(address(timelock));
        fundingRoundManager.startRound{value: roundBudget}(roundBudget, endsAt);

        uint256 currentRoundId = fundingRoundManager.getCurrentRoundId();

        vm.deal(project, 1 ether);
        vm.prank(project);
        uint256 projectId = projectRegistry.registerProject{value: deposit}(
            uri,
            initialLiquidity
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

    function testBuyTokensRevertsIfNotExactETHAmount() external {
        (
            address marketAddress,
            uint256 projectId,
            uint256 roundId
        ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;
        uint256 amountToBuy = 15;
        address user = makeAddr("User");

        vm.prank(address(timelock));
        market.addLiquidity{value: liquidity}();

        uint256 amountToSend = market.getBuyPriceInEth(
            FundingMarket.Side.LONG,
            amountToBuy
        );

        vm.deal(user, 14 ether);

        vm.expectRevert("FundingMarket__MustSendExactETHAmount()");
        vm.prank(user);
        market.buyTokensWithETH{value: amountToSend - 123}(
            FundingMarket.Side.LONG,
            amountToBuy
        );
    }

    function testBuyTokensWithEthEmitsEvent() external {
        (
            address marketAddress,
            uint256 projectId,
            uint256 roundId
        ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;
        uint256 amountToBuy = 15;
        address user = makeAddr("User");

        vm.prank(address(timelock));
        market.addLiquidity{value: liquidity}();

        uint256 amountToSend = market.getBuyPriceInEth(
            FundingMarket.Side.LONG,
            amountToBuy
        );

        vm.deal(user, 14 ether);

        vm.expectEmit(marketAddress);
        emit FundingMarket.TokensBought(amountToBuy, amountToSend);
        vm.prank(user);
        market.buyTokensWithETH{value: amountToSend}(
            FundingMarket.Side.LONG,
            amountToBuy
        );
    }

    //--------------------- sellTokensForEth ---------------------//

    function testSellTokensRevertsIfAmountZero() external {
        (address marketAddress, , ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;
        uint256 amountToSell = 0;

        vm.prank(address(timelock));
        market.addLiquidity{value: liquidity}();

        vm.expectRevert("FundingMarket__AmountMustBeGreaterThanZero()");
        market.sellTokensForEth(FundingMarket.Side.LONG, amountToSell);
    }

    function testSellTokensRevertsIfMarketAlreadyFinalized() external {
        (
            address marketAddress,
            uint256 projectId,
            uint256 roundId
        ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;
        uint256 amountToBuy = 15;
        uint256 amountToSell = 5;
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
        market.sellTokensForEth(FundingMarket.Side.LONG, amountToSell);
    }

    function testSellTokensRevertsIfRoundAlreadyEnded() external {
        (
            address marketAddress,
            uint256 projectId,
            uint256 roundId
        ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;
        uint8 projectScore = 70;
        uint256 amountToSell = 5;

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

        vm.expectRevert("FundingMarket__RoundAlreadyEnded()");
        market.sellTokensForEth(FundingMarket.Side.LONG, amountToSell);
    }

    function testSellTokensForEthRevertsIfUserHasInsufficientBalance()
        external
    {
        (
            address marketAddress,
            uint256 projectId,
            uint256 roundId
        ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;
        uint256 amountToSell = 5;
        address user = makeAddr("User");

        vm.prank(address(timelock));
        market.addLiquidity{value: liquidity}();

        vm.expectRevert(
            abi.encodeWithSelector(
                FundingMarket__InsufficientBalance.selector,
                amountToSell,
                0
            )
        );
        vm.prank(user);
        market.sellTokensForEth(FundingMarket.Side.LONG, amountToSell);
    }

    function testSellTokensForEthRevertsIfInsufficientAllowance() external {
        (
            address marketAddress,
            uint256 projectId,
            uint256 roundId
        ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;
        uint8 projectScore = 70;
        uint256 amountToBuy = 15;
        uint256 amountToSell = 5;
        address user = makeAddr("User");

        vm.prank(address(timelock));
        market.addLiquidity{value: liquidity}();

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

        vm.expectRevert(
            abi.encodeWithSelector(
                FundingMarket__InsufficientAllowance.selector,
                amountToSell,
                0
            )
        );
        vm.prank(user);
        market.sellTokensForEth(FundingMarket.Side.LONG, amountToSell);
    }

    function testSellTokensForEthEmitsEvent() external {
        (
            address marketAddress,
            uint256 projectId,
            uint256 roundId
        ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;
        uint256 amountToBuy = 15;
        uint256 amountToSell = 5;
        address user = makeAddr("User");

        vm.prank(address(timelock));
        market.addLiquidity{value: liquidity}();

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

        FundingMarketToken token = FundingMarketToken(market.getLongToken());

        vm.prank(user);
        token.approve(marketAddress, amountToSell);

        uint256 amountEthReceive = market.getSellPriceInEth(
            FundingMarket.Side.LONG,
            amountToSell
        );

        vm.expectEmit(marketAddress);
        emit FundingMarket.TokensSold(amountToSell, amountEthReceive);
        vm.prank(user);
        market.sellTokensForEth(FundingMarket.Side.LONG, amountToSell);
    }

    //--------------------- redeemLong ---------------------//

    function testRedeemLongRevertsIfAmountZero() external {
        (address marketAddress, , ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 amountToRedeem = 0;
        address user = makeAddr("User");

        vm.expectRevert("FundingMarket__AmountMustBeGreaterThanZero()");
        vm.prank(user);
        market.redeemLong(amountToRedeem);
    }

    function testRedeemLongRevertsIfInsufficientTokenBalance() external {
        (
            address marketAddress,
            uint256 projectId,
            uint256 roundId
        ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 1 ether;
        uint256 amountToRedeem = 100;
        address user = makeAddr("User");
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

        vm.expectRevert("FundingMarket__InsufficientLongBalance()");
        vm.prank(user);
        market.redeemLong(amountToRedeem);
    }

    function testRedeemLongEmitsEvent() external {
        (
            address marketAddress,
            uint256 projectId,
            uint256 roundId
        ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 10 ether;
        uint256 amountToRedeem = 1000;
        address user = makeAddr("User");
        uint8 projectScore = 70;
        uint256 amountToBuy = 1000;
        uint256 INITIAL_TOKEN_VALUE = 1e16;

        vm.prank(address(timelock));
        market.addLiquidity{value: liquidity}();

        uint256 amountToSend = market.getBuyPriceInEth(
            FundingMarket.Side.LONG,
            amountToBuy
        );

        console.log("Amount eth sent:", amountToSend);

        vm.deal(user, 14000 ether);
        vm.prank(user);
        market.buyTokensWithETH{value: amountToSend}(
            FundingMarket.Side.LONG,
            amountToBuy
        );

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

        uint256 payout = (amountToRedeem * INITIAL_TOKEN_VALUE * projectScore) /
            100;

        vm.expectEmit(marketAddress);
        emit FundingMarket.RedeemedLong(amountToRedeem, payout);
        vm.prank(user);
        market.redeemLong(amountToRedeem);
    }

    //--------------------- redeemShort ---------------------//

    function testRedeemShortRevertsIfAmountZero() external {
        (address marketAddress, , ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 amountToRedeem = 0;
        address user = makeAddr("User");

        vm.expectRevert("FundingMarket__AmountMustBeGreaterThanZero()");
        vm.prank(user);
        market.redeemShort(amountToRedeem);
    }

    function testRedeemShortRevertsIfInsufficientTokenBalance() external {
        (
            address marketAddress,
            uint256 projectId,
            uint256 roundId
        ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 10 ether;
        uint256 amountToRedeem = 100;
        address user = makeAddr("User");
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

        vm.expectRevert("FundingMarket__InsufficientShortBalance()");
        vm.prank(user);
        market.redeemShort(amountToRedeem);
    }

    function testRedeemShortEmitsEvent() external {
        (
            address marketAddress,
            uint256 projectId,
            uint256 roundId
        ) = getMarketAddress();
        FundingMarket market = FundingMarket(payable(marketAddress));
        uint256 liquidity = 10 ether;
        uint256 amountToRedeem = 1000;
        address user = makeAddr("User");
        uint8 projectScore = 70;
        uint256 amountToBuy = 1000;
        uint256 INITIAL_TOKEN_VALUE = 1e16;

        vm.prank(address(timelock));
        market.addLiquidity{value: liquidity}();

        uint256 amountToSend = market.getBuyPriceInEth(
            FundingMarket.Side.SHORT,
            amountToBuy
        );

        console.log("Amount eth sent:", amountToSend);

        vm.deal(user, 14000 ether);
        vm.prank(user);
        market.buyTokensWithETH{value: amountToSend}(
            FundingMarket.Side.SHORT,
            amountToBuy
        );

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

        uint256 payout = (amountToRedeem *
            INITIAL_TOKEN_VALUE *
            (100 - projectScore)) / 100;

        vm.expectEmit(marketAddress);
        emit FundingMarket.RedeemedShort(amountToRedeem, payout);
        vm.prank(user);
        market.redeemShort(amountToRedeem);
    }
}
