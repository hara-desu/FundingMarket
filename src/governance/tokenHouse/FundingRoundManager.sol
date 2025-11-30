// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IProjectRegistry, IEvaluatorGovernor, IFundingMarket, IRoundManager} from "@src/Interfaces.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error FundingRoundManager__BudgetCannotBeZero();
error FundingRoundManager_SendTheRightBudgetAmount();
error FundingRoundManager__AnotherRoundOngoing();
error FundingRoundManager__NoOngoingRounds();
error FundingRoundManager__RoundHasNotEnded();
error FundingRoundManager__TranferFailed();
error FundingRoundManager_NothingToPay();
error FundingRoundManager__AddressCannotBeZero();
error FundingRoundManager__EndTimeMustBeInTheFuture();
error FundingRoundManager__InvalidRoundId();

contract FundingRoundManager is IRoundManager, ReentrancyGuard {
    struct Round {
        uint256 roundId;
        uint256 roundBudget;
        uint256 roundSpent;
        uint256 roundRemaining;
        uint256 startsAt;
        uint256 endsAt;
        bool ongoing;
    }

    IProjectRegistry private immutable i_projectRegistry;
    IFundingMarket private immutable i_fundingMarket;
    IEvaluatorGovernor private i_evaluatorGovernor;
    address private immutable i_treasury;

    uint256 private constant EVALUATOR_SCORE_WEIGHT = 80;
    uint256 private constant MARKET_SCORE_WEIGHT = 20;

    uint256 private s_roundId;
    bool private s_roundOngoing;
    uint256 private s_currentRoundId;

    mapping(uint256 => Round) private s_rounds;
    mapping(address => uint256) private s_payouts;

    event RoundStarted(
        uint256 indexed s_roundId,
        uint256 _roundBudget,
        uint256 _endsAt
    );

    event RoundEnded(
        uint256 indexed roundId,
        uint256 capPerProject,
        uint256 returnAmount
    );

    event PaymentsWithdrawn(address indexed recepient, uint256 payout);

    modifier onlyTreasury() {
        require(msg.sender == i_treasury, "Only Treasury allowed");
        _;
    }

    constructor(
        address _treasury,
        address _projectRegistry,
        address _evaluatorGovernor,
        address _fundingMarket
    ) {
        if (
            _treasury == address(0) ||
            _projectRegistry == address(0) ||
            _evaluatorGovernor == address(0) ||
            _fundingMarket == address(0)
        ) {
            revert FundingRoundManager__AddressCannotBeZero();
        }

        i_treasury = _treasury;
        i_projectRegistry = IProjectRegistry(_projectRegistry);
        i_evaluatorGovernor = IEvaluatorGovernor(_evaluatorGovernor);
        i_fundingMarket = IFundingMarket(_fundingMarket);
    }

    function startRound(
        uint256 _roundBudget,
        uint256 _endsAt
    ) external payable onlyTreasury nonReentrant {
        if (_endsAt <= block.timestamp) {
            revert FundingRoundManager__EndTimeMustBeInTheFuture();
        }
        if (_roundBudget == 0) {
            revert FundingRoundManager__BudgetCannotBeZero();
        }
        if (_roundBudget != msg.value) {
            revert FundingRoundManager_SendTheRightBudgetAmount();
        }
        if (s_roundOngoing) {
            revert FundingRoundManager__AnotherRoundOngoing();
        }
        s_roundId++;
        s_rounds[s_roundId] = Round({
            roundId: s_roundId,
            roundBudget: _roundBudget,
            roundSpent: 0,
            roundRemaining: _roundBudget,
            startsAt: block.timestamp,
            endsAt: _endsAt,
            ongoing: true
        });

        s_roundOngoing = true;
        s_currentRoundId = s_roundId;

        emit RoundStarted(s_roundId, _roundBudget, _endsAt);
    }

    function endCurrentRound() external onlyTreasury nonReentrant {
        if (s_currentRoundId == 0) {
            revert FundingRoundManager__NoOngoingRounds();
        }
        if (s_rounds[s_currentRoundId].endsAt > block.timestamp) {
            revert FundingRoundManager__RoundHasNotEnded();
        }
        uint256 roundId = s_currentRoundId;

        // Change state before paying
        s_rounds[roundId].ongoing = false;
        s_roundOngoing = false;
        s_currentRoundId = 0;

        uint256[] memory projectIds = i_projectRegistry.getProjectsForRound(
            roundId
        );

        uint256 projectCount = projectIds.length;
        if (projectCount == 0) {
            // No projects: just return entire budget to TokenHouse
            uint256 returnAmount = s_rounds[roundId].roundRemaining;
            s_rounds[roundId].roundRemaining = 0;
            (bool success, ) = payable(i_treasury).call{value: returnAmount}(
                ""
            );
            if (!success) revert FundingRoundManager__TranferFailed();
            return;
        }

        uint256 capPerProject = s_rounds[roundId].roundBudget / projectCount;

        for (uint256 i = 0; i < projectIds.length; i++) {
            uint256 projectId = projectIds[i];
            uint256 evaluatorScore = i_evaluatorGovernor
                .getImpactScoreForProject(roundId, projectId);
            uint256 marketScore = i_fundingMarket.getMarketScore(projectId);

            // Pay to the project
            uint256 finalScore = (EVALUATOR_SCORE_WEIGHT *
                evaluatorScore +
                MARKET_SCORE_WEIGHT *
                marketScore) / 100;
            uint256 payment = (capPerProject * finalScore) / 100;
            s_rounds[roundId].roundSpent += payment;
            s_rounds[roundId].roundRemaining -= payment;
            (address projectOwner, , ) = i_projectRegistry.getProject(
                projectId
            );
            s_payouts[projectOwner] += payment;
        }

        // Send the remaining budget back to TokenHouseGovernor
        uint256 returnAmount = s_rounds[roundId].roundRemaining;
        s_rounds[roundId].roundRemaining = 0;
        (bool success, ) = payable(i_treasury).call{value: returnAmount}("");
        if (!success) {
            revert FundingRoundManager__TranferFailed();
        }

        emit RoundEnded(roundId, capPerProject, returnAmount);
    }

    function withdrawAllPayments() external nonReentrant {
        uint256 payout = s_payouts[msg.sender];
        if (payout == 0) {
            revert FundingRoundManager_NothingToPay();
        }
        s_payouts[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: payout}("");
        if (!success) {
            revert FundingRoundManager__TranferFailed();
        }

        emit PaymentsWithdrawn(msg.sender, payout);
    }

    //----------------- Getter Functions -----------------//

    function getCurrentRoundId() external view returns (uint256) {
        return s_currentRoundId;
    }

    function hasRoundEnded(uint256 _roundId) external view returns (bool) {
        Round storage r = s_rounds[_roundId];
        if (r.roundId == 0) {
            return false;
        }
        return !r.ongoing || block.timestamp >= r.endsAt;
    }

    function getRound(
        uint256 _roundId
    )
        external
        view
        returns (
            uint256 roundBudget,
            uint256 roundSpent,
            uint256 roundRemaining,
            uint256 startsAt,
            uint256 endsAt,
            bool ongoing
        )
    {
        Round storage r = s_rounds[_roundId];
        if (r.roundId == 0) {
            revert FundingRoundManager__InvalidRoundId();
        }
        return (
            r.roundBudget,
            r.roundSpent,
            r.roundRemaining,
            r.startsAt,
            r.endsAt,
            r.ongoing
        );
    }

    function getPayout(address _user) external view returns (uint256) {
        return s_payouts[_user];
    }

    function isAnyRoundOngoing() external view returns (bool) {
        return s_roundOngoing;
    }

    function getScoreWeights()
        external
        pure
        returns (uint256 evaluatorWeight, uint256 marketWeight)
    {
        return (EVALUATOR_SCORE_WEIGHT, MARKET_SCORE_WEIGHT);
    }
}
