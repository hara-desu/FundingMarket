// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IEvaluatorSBT} from "@src/Interfaces.sol";

contract FundingMarketToken is ERC20 {
    error FundingMarketToken__OnlyPredictionMarketCanMint();
    error FundingMarketToken__OnlyPredictionMarketCanBurn();
    error FundingMarketToken__LiquidityProviderCantTransfer();
    error FundingMarketToken__CantTransferToEvaluator();

    address public predictionMarket;
    address public liquidityProvider;
    IEvaluatorSBT public evaluatorSbt;

    constructor(
        string memory name,
        string memory symbol,
        address _liquidityProvider,
        uint256 _initialSupply,
        address _evaluatorSbt
    ) ERC20(name, symbol) {
        predictionMarket = msg.sender;
        liquidityProvider = _liquidityProvider;
        evaluatorSbt = IEvaluatorSBT(_evaluatorSbt);
        _mint(msg.sender, _initialSupply);
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != predictionMarket) {
            revert FundingMarketToken__OnlyPredictionMarketCanMint();
        }
        if (evaluatorSbt.isEvaluator(to)) {
            revert FundingMarketToken__CantTransferToEvaluator();
        }
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        if (msg.sender != predictionMarket) {
            revert FundingMarketToken__OnlyPredictionMarketCanBurn();
        }
        _burn(from, amount);
    }

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (msg.sender == liquidityProvider) {
            revert FundingMarketToken__LiquidityProviderCantTransfer();
        }
        if (evaluatorSbt.isEvaluator(to)) {
            revert FundingMarketToken__CantTransferToEvaluator();
        }
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (from == liquidityProvider) {
            revert FundingMarketToken__LiquidityProviderCantTransfer();
        }
        if (evaluatorSbt.isEvaluator(to)) {
            revert FundingMarketToken__CantTransferToEvaluator();
        }
        return super.transferFrom(from, to, amount);
    }
}
