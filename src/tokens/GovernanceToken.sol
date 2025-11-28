// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.18;

// import {IEvaluatorSBT} from "@src/Interfaces.sol";

// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
// import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

// contract GovernanceToken is ERC20, ERC20Permit, ERC20Votes {
//     error GovernanceToken__EvaluatorCannotReceiveMint();
//     error GovernanceToken__ZeroAddress();
//     error GovernanceToken__NotMinter();

//     IEvaluatorSBT public immutable evaluatorSbt;
//     address public immutable i_minter;

//     constructor(
//         address _evaluatorSbt,
//         address _minter,
//         address _initialRecipient,
//         uint256 _initialSupply
//     ) ERC20("Fun DAO Token", "FUND") ERC20Permit("Fun DAO Token") {
//         if (_evaluatorSbt == address(0) || _minter == address(0)) {
//             revert GovernanceToken__ZeroAddress();
//         }

//         evaluatorSbt = IEvaluatorSBT(_evaluatorSbt);
//         i_minter = _minter;

//         if (_initialRecipient != address(0) && _initialSupply > 0) {
//             _mint(_initialRecipient, _initialSupply);
//         }
//     }

//     modifier onlyMinter() {
//         if (msg.sender != i_minter) {
//             revert GovernanceToken__NotMinter();
//         }
//         _;
//     }

//     function mint(address _to, uint256 _amount) external onlyMinter {
//         if (_to == address(0)) {
//             revert GovernanceToken__ZeroAddress();
//         }
//         if (evaluatorSbt.isEvaluator(_to)) {
//             revert GovernanceToken__EvaluatorCannotReceiveMint();
//         }
//         _mint(_to, _amount);
//     }

//     // ---------- Required overrides for ERC20Votes ----------

//     function _afterTokenTransfer(
//         address from,
//         address to,
//         uint256 amount
//     ) internal override(ERC20, ERC20Votes) {
//         super._afterTokenTransfer(from, to, amount);
//     }

//     function _mint(
//         address to,
//         uint256 amount
//     ) internal override(ERC20, ERC20Votes) {
//         super._mint(to, amount);
//     }

//     function _burn(
//         address account,
//         uint256 amount
//     ) internal override(ERC20, ERC20Votes) {
//         super._burn(account, amount);
//     }
// }
