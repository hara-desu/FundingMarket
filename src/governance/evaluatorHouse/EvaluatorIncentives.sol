// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IEvaluatorSBT, IRoundManager} from "@src/Interfaces.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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

contract EvaluatorIncentives is ReentrancyGuard {
    IEvaluatorSBT private immutable i_evaluatorSbt;
    IRoundManager private immutable i_roundManager;
    address private immutable i_timelock;

    // roundId => budget
    mapping(uint256 => uint256) private s_roundBudget;
    // roundId => funded?
    mapping(uint256 => bool) private s_isFunded;
    // roundid => evaluator => registered?
    mapping(uint256 => mapping(address => bool)) private s_registeredForPayout;
    // roundId => numRegistered
    mapping(uint256 => uint256) private s_countRegistered;
    mapping(uint256 => mapping(address => bool)) private s_hasClaimed;

    event RoundFunded(uint256 indexed roundId, uint256 amount);

    event RegisteredForPayout(
        uint256 indexed roundId,
        address indexed receiver
    );

    event RewardWithdrawn(
        uint256 indexed roundId,
        address indexed receiver,
        uint256 amount
    );

    modifier onlyTimelock() {
        require(
            msg.sender == i_timelock,
            "Only Timelock can call this function"
        );
        _;
    }

    modifier onlyEvaluator() {
        bool isEvaluator = i_evaluatorSbt.isEvaluator(msg.sender);
        require(isEvaluator, "Only evaluators allowed");
        _;
    }

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
        i_evaluatorSbt = IEvaluatorSBT(_evaluatorSbt);
        i_roundManager = IRoundManager(_roundManager);
    }

    receive() external payable {
        revert("Use fundRound()");
    }

    function fundRound() external payable onlyTimelock {
        uint256 currentRoundId = i_roundManager.getCurrentRoundId();
        if (currentRoundId == 0)
            revert EvaluatorIncentives__RoundDoesNotExist();

        bool roundEnded = i_roundManager.hasRoundEnded(currentRoundId);
        if (roundEnded) {
            revert EvaluatorIncentives__RoundEnded();
        }

        if (s_isFunded[currentRoundId]) {
            revert EvaluatorIncentives__RoundAlreadyFunded();
        }

        s_roundBudget[currentRoundId] = msg.value;
        s_isFunded[currentRoundId] = true;

        emit RoundFunded(currentRoundId, msg.value);
    }

    function registerForRoundPayout(uint256 _roundId) external onlyEvaluator {
        bool roundEnded = i_roundManager.hasRoundEnded(_roundId);
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
        emit RegisteredForPayout(_roundId, msg.sender);
    }

    function withdrawReward(
        uint256 _roundId
    ) external onlyEvaluator nonReentrant {
        bool roundEnded = i_roundManager.hasRoundEnded(_roundId);
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

        emit RewardWithdrawn(_roundId, msg.sender, payout);
    }

    //----------------- Getter Functions -----------------//

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

    function isRoundFunded(uint256 _roundId) external view returns (bool) {
        return s_isFunded[_roundId];
    }

    function getPayoutPerEvaluator(
        uint256 _roundId
    ) external view returns (uint256) {
        if (!s_isFunded[_roundId]) {
            return 0;
        }
        uint256 count = s_countRegistered[_roundId];
        if (count == 0) {
            return 0;
        }
        return s_roundBudget[_roundId] / count;
    }

    function canWithdraw(
        uint256 _roundId,
        address _evaluator
    ) external view returns (bool) {
        if (!s_isFunded[_roundId]) return false;
        if (!s_registeredForPayout[_roundId][_evaluator]) return false;
        if (s_hasClaimed[_roundId][_evaluator]) return false;
        if (!i_roundManager.hasRoundEnded(_roundId)) return false;
        if (s_countRegistered[_roundId] == 0) return false;

        return true;
    }
}
