// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.18;

// import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
// import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
// import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
// import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
// import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
// import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
// import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

// import {IEvaluatorSBT} from "@src/Interfaces.sol";

// /// @title TokenHouseGovernor
// /// @notice Governance for:
// ///  1. Allocating money for funding rounds (calls FundingRoundManager.startRound / etc)
// ///  2. Contract upgrades (UUPS / proxy admin calls)
// ///  3. Funding market parameters (calls FundingMarket config functions)
// ///  4. Other treasury spending
// ///  5. Evaluator incentives (set per-round rewards, etc.)
// ///  6. Bounty payouts for detecting manipulation or fraud.
// contract TokenHouseGovernor is
//     Governor,
//     GovernorCountingSimple,
//     GovernorVotes,
//     GovernorVotesQuorumFraction,
//     GovernorTimelockControl
// {
//     IEvaluatorSBT public immutable evaluatorSbt;

//     constructor(
//         IVotes _token,
//         TimelockController _timelock,
//         IEvaluatorSBT _evaluatorSbt
//     )
//         Governor("Fun DAO Token House")
//         GovernorVotes(_token)
//         GovernorVotesQuorumFraction(4)
//         GovernorTimelockControl(_timelock)
//     {
//         evaluatorSbt = _evaluatorSbt;
//     }

//     function votingDelay() public pure override returns (uint256) {
//         return 7200;
//     }

//     function votingPeriod() public pure override returns (uint256) {
//         return 50400;
//     }

//     function proposalThreshold() public pure override returns (uint256) {
//         return 0;
//     }

//     function quorum(
//         uint256 timepoint
//     )
//         public
//         view
//         override(Governor, GovernorVotesQuorumFraction)
//         returns (uint256)
//     {
//         return super.quorum(timepoint);
//     }

//     /// Evaluators (SBT holders) get 0 voting power in the Token House.
//     function _getVotes(
//         address account,
//         uint256 timepoint,
//         bytes memory params
//     ) internal view override(Governor, GovernorVotes) returns (uint256) {
//         if (evaluatorSbt.isEvaluator(account)) {
//             return 0;
//         }
//         return super._getVotes(account, timepoint, params);
//     }

//     function state(
//         uint256 proposalId
//     )
//         public
//         view
//         override(Governor, GovernorTimelockControl)
//         returns (ProposalState)
//     {
//         return super.state(proposalId);
//     }

//     function _execute(
//         uint256 proposalId,
//         address[] memory targets,
//         uint256[] memory values,
//         bytes[] memory calldatas,
//         bytes32 descriptionHash
//     ) internal override(Governor, GovernorTimelockControl) {
//         super._execute(proposalId, targets, values, calldatas, descriptionHash);
//     }

//     function _cancel(
//         address[] memory targets,
//         uint256[] memory values,
//         bytes[] memory calldatas,
//         bytes32 descriptionHash
//     ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
//         return super._cancel(targets, values, calldatas, descriptionHash);
//     }

//     function _executor()
//         internal
//         view
//         override(Governor, GovernorTimelockControl)
//         returns (address)
//     {
//         // This returns the TimelockController address.
//         return super._executor();
//     }

//     function supportsInterface(
//         bytes4 interfaceId
//     ) public view override(Governor, GovernorTimelockControl) returns (bool) {
//         return super.supportsInterface(interfaceId);
//     }
// }
