// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.27;

import {IEvaluatorSBT} from "@src/Interfaces.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FunDAOToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    error FunDAOToken__EvaluatorCannotReceiveTokens();

    /// @notice SBT contract used to determine who is an evaluator.
    IEvaluatorSBT public immutable evaluatorSbt;

    constructor(
        address recipient,
        address timelockAddress,
        IEvaluatorSBT evaluatorSbt
    )
        ERC20("FunDAO Token", "FUND")
        ERC20Permit("FunDAO Token")
        Ownable(timelockAddress)
    {
        require(recipient != address(0), "Zero initial recipient");
        require(timelockAddress != address(0), "Zero timelock");
        require(address(evaluatorSbt) != address(0), "Zero EvaluatorSBT");

        evaluatorSbt = evaluatorSbt;

        _mint(recipient, 1000 * 10 ** decimals());
    }

    /// @notice Mint new FUND tokens. Only the timelock (owner) can call this.
    /// @dev Governance proposals that mint will be executed by the timelock.
    function mint(address _to, uint256 _amount) external onlyOwner {
        // Evaluators cannot receive FUND.
        if (evaluatorSbt.isEvaluator(_to)) {
            revert FunDAOToken__EvaluatorCannotReceiveTokens();
        }
        _mint(_to, _amount);
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Votes) {
        // Block *any* transfer or mint *to* an evaluator.
        if (to != address(0) && evaluatorSbt.isEvaluator(to)) {
            revert FunDAOToken__EvaluatorCannotReceiveTokens();
        }

        super._update(from, to, value);
    }

    function nonces(
        address owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
