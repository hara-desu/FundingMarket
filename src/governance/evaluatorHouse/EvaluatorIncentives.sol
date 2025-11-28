// TODO:
// 1. Add participation check for evaluators: percentage of projects they voted on in a round
// 2. Add events

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IEvaluatorSBT, IRoundManager} from "@src/Interfaces.sol";

contract EvaluatorIncentives {
    error EvaluatorIncentives__RoundEnded();
    error EvaluatorIncentives__RoundAlreadyFunded();
    error EvaluatorIncentives__RoundNotEndedYet();
    error EvaluatorIncentives__DidNotRegisterForPayout();
    error EvaluatorIncentives__TransactionFailed();
    error EvaluatorIncentives__PayoutAlreadyCalimed();
    error EvaluatorIncentives__NobodyHasRegisteredForPayout();
    error EvaluatorIncentives__RoundNotFunded();
    error EvaluatorIncentives__RoundDoesNotExist();
    error EvaluatorIncentives__ZeroAddressNotAllowed();
    error EvaluatorIncentives__AlreadyRegistered();

    IEvaluatorSBT public immutable evaluatorSbt;
    IRoundManager public immutable roundManager;
    address public immutable i_timelock;
    // roundId => budget
    mapping(uint256 => uint256) private s_roundBudget;
    // roundId => funded?
    mapping(uint256 => bool) private s_isFunded;
    // roundid => evaluator => registered?
    mapping(uint256 => mapping(address => bool)) private s_registeredForPayout;
    // roundId => numRegistered
    mapping(uint256 => uint256) private s_countRegistered;
    mapping(uint256 => mapping(address => bool)) private s_hasClaimed;

    constructor(
        address _timelock,
        address _evaluatorSbt,
        address _roundManager
    ) {
        if (
            _timelock == address(0) ||
            _evaluatorSbt == address(0) ||
            _roundManager == address(0)
        ) {
            revert EvaluatorIncentives__ZeroAddressNotAllowed();
        }
        i_timelock = _timelock;
        evaluatorSbt = IEvaluatorSBT(_evaluatorSbt);
        roundManager = IRoundManager(_roundManager);
    }

    modifier onlyTimelock() {
        require(
            msg.sender == i_timelock,
            "Only Timelock can call this function"
        );
        _;
    }

    modifier onlyEvaluator() {
        bool isEvaluator = evaluatorSbt.isEvaluator(msg.sender);
        require(isEvaluator, "Only evaluators allowed");
        _;
    }

    function fundRound() external payable onlyTimelock {
        uint256 currentRoundId = roundManager.getCurrentRoundId();
        if (currentRoundId == 0)
            revert EvaluatorIncentives__RoundDoesNotExist();

        bool roundEnded = roundManager.hasRoundEnded(currentRoundId);
        if (roundEnded) {
            revert EvaluatorIncentives__RoundEnded();
        }

        if (s_isFunded[currentRoundId]) {
            revert EvaluatorIncentives__RoundAlreadyFunded();
        }

        s_roundBudget[currentRoundId] = msg.value;
        s_isFunded[currentRoundId] = true;
    }

    function registerForRoundPayout(uint256 _roundId) external onlyEvaluator {
        bool roundEnded = roundManager.hasRoundEnded(_roundId);
        if (roundEnded) {
            revert EvaluatorIncentives__RoundEnded();
        }

        if (!s_isFunded[_roundId]) {
            revert EvaluatorIncentives__RoundNotFunded();
        }

        if (!s_registeredForPayout[_roundId][msg.sender]) {
            s_registeredForPayout[_roundId][msg.sender] = true;
            s_countRegistered[_roundId] += 1;
        } else {
            revert EvaluatorIncentives__AlreadyRegistered();
        }
    }

    function withdrawReward(uint256 _roundId) external onlyEvaluator {
        bool roundEnded = roundManager.hasRoundEnded(_roundId);
        if (!roundEnded) {
            revert EvaluatorIncentives__RoundNotEndedYet();
        }

        if (!s_isFunded[_roundId]) revert EvaluatorIncentives__RoundNotFunded();

        bool registered = s_registeredForPayout[_roundId][msg.sender];
        if (!registered) {
            revert EvaluatorIncentives__DidNotRegisterForPayout();
        }

        if (s_countRegistered[_roundId] == 0) {
            revert EvaluatorIncentives__NobodyHasRegisteredForPayout();
        }

        uint256 payout = s_roundBudget[_roundId] / s_countRegistered[_roundId];

        if (s_hasClaimed[_roundId][msg.sender] == true) {
            revert EvaluatorIncentives__PayoutAlreadyCalimed();
        }

        s_hasClaimed[_roundId][msg.sender] = true;

        (bool success, ) = payable(msg.sender).call{value: payout}("");
        if (!success) revert EvaluatorIncentives__TransactionFailed();
    }

    /* Getter functions */

    function getRoundBudget(uint256 _roundId) external view returns (uint256) {
        return s_roundBudget[_roundId];
    }

    function getRegisteredCount(
        uint256 _roundId
    ) external view returns (uint256) {
        return s_countRegistered[_roundId];
    }

    function hasRegistered(
        uint256 _roundId,
        address _evaluator
    ) external view returns (bool) {
        return s_registeredForPayout[_roundId][_evaluator];
    }

    function hasClaimed(
        uint256 _roundId,
        address _evaluator
    ) external view returns (bool) {
        return s_hasClaimed[_roundId][_evaluator];
    }
}
