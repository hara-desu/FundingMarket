// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FundingMarketToken} from "@src/tokens/FundingMarketToken.sol";
import {IEvaluatorSBT, IEvaluatorGovernor, IFundingMarket} from "@src/Interfaces.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IRoundManager} from "@src/governance/tokenHouse/FundingRoundManager.sol";

error FundingMarket__MustProvideETHForInitialLiquidity();
error FundingMarket__CannotProvideZeroAddress();
error FundingMarket__AmountMustBeGreaterThanZero();
error FundingMarket__InsufficientTokenReserve(uint8 side, uint256 amount);
error FundingMarket__TokenTransferFailed();
error FundingMarket__ETHTransferFailed();
error FundingMarket__InsufficientBalance(
    uint256 tradingAmount,
    uint256 userBalance
);
error FundingMarket__InsufficientAllowance(
    uint256 tradingAmount,
    uint256 allowance
);
error FundingMarket__InsufficientLiquidity();
error FundingMarket__AlreadyFinalized();
error FundingMarket__InvalidScore();
error FundingMarket__InsufficientLongBalance();
error FundingMarket__InsufficientShortBalance();
error FundingMarket__MustSendExactETHAmount();
error FundingMarket__RoundAlreadyEnded();

contract FundingMarket is Ownable, IFundingMarket, ReentrancyGuard {
    enum Side {
        LONG, // pays S/100
        SHORT // pays (100-S)/100
    }

    address private immutable i_evaluatorGovernor;
    IEvaluatorSBT private immutable i_evaluatorSbt;
    IEvaluatorGovernor private immutable i_evaluatorGovernorContract;
    IRoundManager private immutable i_roundManager;

    FundingMarketToken private immutable i_longToken;
    FundingMarketToken private immutable i_shortToken;

    uint256 private constant INITIAL_TOKEN_VALUE = 1e16;
    uint256 private constant PRECISION = 1e18;
    uint256 private immutable i_projectId;
    uint256 private immutable i_roundId;
    uint256 private s_ethCollateral;
    uint256 private s_lpTradingRevenue;
    bool private s_isFinalized;
    uint8 private s_finalScore; // 0–100

    event LiquidityAdded(uint256 amount);
    event LiquidityRemoved(uint256 ethWithdrawn, uint256 tokensBurnt);
    event TokensBought(uint256 amountTokens, uint256 amountWei);
    event TokensSold(uint256 amountTokens, uint256 amountWei);
    event RedeemedLong(uint256 amountTokens, uint256 amountWei);
    event RedeemedShort(uint256 amountTokens, uint256 amountWei);

    modifier amountGreaterThanZero(uint256 _amount) {
        if (_amount == 0) {
            revert FundingMarket__AmountMustBeGreaterThanZero();
        }
        _;
    }

    constructor(
        uint256 _projectId,
        uint256 _roundId,
        address _evaluatorGovernor,
        address _timelock,
        address _evaluatorSbt,
        address _roundManager
    ) payable Ownable(_timelock) {
        if (
            _evaluatorGovernor == address(0) ||
            _timelock == address(0) ||
            _evaluatorSbt == address(0) ||
            _roundManager == address(0)
        ) {
            revert FundingMarket__CannotProvideZeroAddress();
        }

        i_projectId = _projectId;
        i_roundId = _roundId;
        i_evaluatorGovernor = _evaluatorGovernor;
        i_evaluatorSbt = IEvaluatorSBT(_evaluatorSbt);
        i_evaluatorGovernorContract = IEvaluatorGovernor(_evaluatorGovernor);
        i_roundManager = IRoundManager(_roundManager);

        i_longToken = new FundingMarketToken(
            "Impact LONG",
            "ILONG",
            _timelock,
            0,
            _evaluatorSbt
        );

        i_shortToken = new FundingMarketToken(
            "Impact SHORT",
            "ISHORT",
            _timelock,
            0,
            _evaluatorSbt
        );
    }

    receive() external payable {
        s_ethCollateral += msg.value;
    }

    fallback() external payable {
        revert("Invalid call");
    }

    function addLiquidity() external payable onlyOwner {
        // msg.value is the DAO capital for this market
        s_ethCollateral += msg.value;

        uint256 tokensToMint = (msg.value * PRECISION) / INITIAL_TOKEN_VALUE;
        i_longToken.mint(address(this), tokensToMint);
        i_shortToken.mint(address(this), tokensToMint);

        emit LiquidityAdded(msg.value);
    }

    function removeLiquidity(
        uint256 _ethToWithdraw
    ) external onlyOwner nonReentrant {
        uint256 tokensToBurn = (_ethToWithdraw * PRECISION) /
            INITIAL_TOKEN_VALUE;

        if (tokensToBurn > i_longToken.balanceOf(address(this))) {
            revert FundingMarket__InsufficientTokenReserve(
                uint8(Side.LONG),
                tokensToBurn
            );
        }
        if (tokensToBurn > i_shortToken.balanceOf(address(this))) {
            revert FundingMarket__InsufficientTokenReserve(
                uint8(Side.SHORT),
                tokensToBurn
            );
        }

        s_ethCollateral -= _ethToWithdraw;

        i_longToken.burn(address(this), tokensToBurn);
        i_shortToken.burn(address(this), tokensToBurn);

        (bool success, ) = msg.sender.call{value: _ethToWithdraw}("");
        if (!success) {
            revert FundingMarket__ETHTransferFailed();
        }

        emit LiquidityRemoved(_ethToWithdraw, tokensToBurn);
    }

    function buyTokensWithETH(
        Side _side,
        uint256 _amountTokenToBuy
    ) external payable amountGreaterThanZero(_amountTokenToBuy) {
        if (s_isFinalized) revert FundingMarket__AlreadyFinalized();

        if (i_roundManager.hasRoundEnded(i_roundId)) {
            revert FundingMarket__RoundAlreadyEnded();
        }

        uint256 ethNeeded = getBuyPriceInEth(_side, _amountTokenToBuy);
        if (msg.value != ethNeeded) {
            revert FundingMarket__MustSendExactETHAmount();
        }

        FundingMarketToken token = _side == Side.LONG
            ? i_longToken
            : i_shortToken;

        if (_amountTokenToBuy > token.balanceOf(address(this))) {
            revert FundingMarket__InsufficientTokenReserve(
                uint8(_side),
                _amountTokenToBuy
            );
        }

        s_lpTradingRevenue += msg.value;

        bool success = token.transfer(msg.sender, _amountTokenToBuy);
        if (!success) {
            revert FundingMarket__TokenTransferFailed();
        }

        emit TokensBought(_amountTokenToBuy, msg.value);
    }

    function sellTokensForEth(
        Side _side,
        uint256 _tradingAmount
    ) external amountGreaterThanZero(_tradingAmount) nonReentrant {
        if (s_isFinalized) revert FundingMarket__AlreadyFinalized();

        if (i_roundManager.hasRoundEnded(i_roundId)) {
            revert FundingMarket__RoundAlreadyEnded();
        }

        FundingMarketToken token = _side == Side.LONG
            ? i_longToken
            : i_shortToken;
        uint256 userBalance = token.balanceOf(msg.sender);
        if (userBalance < _tradingAmount) {
            revert FundingMarket__InsufficientBalance(
                _tradingAmount,
                userBalance
            );
        }

        uint256 allowance = token.allowance(msg.sender, address(this));
        if (allowance < _tradingAmount) {
            revert FundingMarket__InsufficientAllowance(
                _tradingAmount,
                allowance
            );
        }

        uint256 ethToReceive = getSellPriceInEth(_side, _tradingAmount);

        s_lpTradingRevenue -= ethToReceive;

        bool success = token.transferFrom(
            msg.sender,
            address(this),
            _tradingAmount
        );
        if (!success) {
            revert FundingMarket__TokenTransferFailed();
        }

        (bool sent, ) = msg.sender.call{value: ethToReceive}("");
        if (!sent) {
            revert FundingMarket__ETHTransferFailed();
        }

        emit TokensSold(_tradingAmount, ethToReceive);
    }

    function redeemLong(
        uint256 _amount
    ) external amountGreaterThanZero(_amount) nonReentrant {
        if (!s_isFinalized) {
            _reportFinalScore(); // Reverts if impact proposal in EvaluatorGovernor is not finalized
        }

        if (i_longToken.balanceOf(msg.sender) < _amount) {
            revert FundingMarket__InsufficientLongBalance();
        }

        // payoffPerToken = (finalScore / 100) * INITIAL_TOKEN_VALUE / PRECISION
        uint256 payout = (_amount * INITIAL_TOKEN_VALUE * s_finalScore) /
            (100 * PRECISION);

        s_ethCollateral -= payout;

        i_longToken.burn(msg.sender, _amount);

        (bool success, ) = msg.sender.call{value: payout}("");
        if (!success) revert FundingMarket__ETHTransferFailed();

        emit RedeemedLong(_amount, payout);
    }

    function redeemShort(
        uint256 _amount
    ) external amountGreaterThanZero(_amount) nonReentrant {
        if (!s_isFinalized) {
            _reportFinalScore(); // Reverts if impact proposal in EvaluatorGovernor is not finalized
        }

        if (i_shortToken.balanceOf(msg.sender) < _amount) {
            revert FundingMarket__InsufficientShortBalance();
        }

        uint256 payout = (_amount *
            INITIAL_TOKEN_VALUE *
            (100 - s_finalScore)) / (100 * PRECISION);

        s_ethCollateral -= payout;

        i_shortToken.burn(msg.sender, _amount);

        (bool success, ) = msg.sender.call{value: payout}("");
        if (!success) revert FundingMarket__ETHTransferFailed();

        emit RedeemedShort(_amount, payout);
    }

    function _reportFinalScore() internal {
        if (s_isFinalized) return;

        uint256 score = i_evaluatorGovernorContract.getImpactScoreForProject(
            i_roundId,
            i_projectId
        );

        if (score > 100) revert FundingMarket__InvalidScore();
        s_finalScore = uint8(score);

        s_isFinalized = true;
    }

    function _calculatePriceInEth(
        Side _side,
        uint256 _tradingAmount,
        bool _isSelling
    ) internal view returns (uint256) {
        (uint256 thisReserve, uint256 otherReserve) = _getCurrentReserves(
            _side
        );

        if (!_isSelling && thisReserve < _tradingAmount) {
            revert FundingMarket__InsufficientLiquidity();
        }

        uint256 totalSupply = i_longToken.totalSupply(); // same for both

        // Before trade
        uint256 thisSoldBefore = totalSupply - thisReserve;
        uint256 otherSoldBefore = totalSupply - otherReserve;
        uint256 totalSoldBefore = thisSoldBefore + otherSoldBefore;

        if (totalSoldBefore == 0) {
            // no trades yet -> default mid-price
            // price ~ 0.5 * INITIAL_TOKEN_VALUE per unit
            return (INITIAL_TOKEN_VALUE * _tradingAmount) / 2;
        }

        uint256 probBefore = (thisSoldBefore * PRECISION) / totalSoldBefore;

        // After trade
        uint256 thisReserveAfter = _isSelling
            ? thisReserve + _tradingAmount
            : thisReserve - _tradingAmount;
        uint256 thisSoldAfter = totalSupply - thisReserveAfter;
        uint256 totalSoldAfter = _isSelling
            ? totalSoldBefore - _tradingAmount
            : totalSoldBefore + _tradingAmount;

        uint256 probAfter = (thisSoldAfter * PRECISION) / totalSoldAfter;

        uint256 probAvg = (probBefore + probAfter) / 2;

        // Price per token in ETH: INITIAL_TOKEN_VALUE * probAvg / PRECISION
        return (INITIAL_TOKEN_VALUE * probAvg * _tradingAmount) / (PRECISION);
    }

    //----------------- Getter Functions -----------------//

    function _getCurrentReserves(
        Side _side
    ) internal view returns (uint256, uint256) {
        if (_side == Side.LONG) {
            return (
                i_longToken.balanceOf(address(this)),
                i_shortToken.balanceOf(address(this))
            );
        } else {
            return (
                i_shortToken.balanceOf(address(this)),
                i_longToken.balanceOf(address(this))
            );
        }
    }

    function getMarketScore(
        uint256 _projectId
    ) external view returns (uint256) {
        require(_projectId == i_projectId, "Wrong project id");

        uint256 totalSupply = i_longToken.totalSupply();
        uint256 longReserve = i_longToken.balanceOf(address(this));
        uint256 shortReserve = i_shortToken.balanceOf(address(this));

        uint256 longSold = totalSupply - longReserve;
        uint256 shortSold = totalSupply - shortReserve;
        uint256 totalSold = longSold + shortSold;

        if (totalSold == 0) {
            // no information yet → neutral 50
            return 50;
        }

        uint256 probLong = (longSold * PRECISION) / totalSold; // [0,1] scaled
        uint256 impliedScore = (probLong * 100) / PRECISION; // [0,100]

        return impliedScore;
    }

    function getBuyPriceInEth(
        Side _side,
        uint256 _tradingAmount
    ) public view returns (uint256) {
        return _calculatePriceInEth(_side, _tradingAmount, false);
    }

    function getSellPriceInEth(
        Side _side,
        uint256 _tradingAmount
    ) public view returns (uint256) {
        return _calculatePriceInEth(_side, _tradingAmount, true);
    }

    function getProjectId() external view returns (uint256) {
        return i_projectId;
    }

    function getRoundId() external view returns (uint256) {
        return i_roundId;
    }

    function getLongToken() external view returns (address) {
        return address(i_longToken);
    }

    function getShortToken() external view returns (address) {
        return address(i_shortToken);
    }

    function getInitialTokenValue() external pure returns (uint256) {
        return INITIAL_TOKEN_VALUE;
    }

    function getEthCollateral() external view returns (uint256) {
        return s_ethCollateral;
    }

    function getLpTradingRevenue() external view returns (uint256) {
        return s_lpTradingRevenue;
    }

    function isFinalized() external view returns (bool) {
        return s_isFinalized;
    }

    function getFinalScore() external view returns (uint8) {
        return s_finalScore;
    }

    function getReserves()
        external
        view
        returns (uint256 longReserve, uint256 shortReserve)
    {
        longReserve = i_longToken.balanceOf(address(this));
        shortReserve = i_shortToken.balanceOf(address(this));
    }

    function getTotalSupply() external view returns (uint256) {
        return i_longToken.totalSupply();
    }
}
