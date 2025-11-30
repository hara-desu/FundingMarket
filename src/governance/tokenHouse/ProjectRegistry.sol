// TODO:
// 1. Add events
// 2. Add getters
// 3. Add suppports interface
// 4. Add fallback functions
// 5. Add non-reentrant modifier

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IEvaluatorSBT, IRoundManager, IProjectRegistry} from "@src/Interfaces.sol";
import {FundingMarket} from "@src/market/FundingMarket.sol";

contract ProjectRegistry is IProjectRegistry {
    error ProjectRegistry__ZeroAddressNotAllowed();
    error ProjectRegistry__InvalidRoundId();
    error ProjectRegistry__InvalidMetadataUri();
    error ProjectRegistry__InvalidDepositAmount();
    error ProjectRegistry__TransferFailed();
    error ProjectRegistry__NoDepositFound();
    error ProjectRegistry__RoundOngoing();
    error ProjectRegistry__NotEnoughBalance();
    error ProjectRegistry__RoundEnded();
    error ProjectRegistry__InvalidProjectId();
    error FundingMarketFactory__MarketAlreadyExists();

    IRoundManager public roundManager;
    IEvaluatorSBT public evaluatorSbt;

    address public immutable i_evaluatorGovernor; // to create market
    address public immutable i_timelock; // to create market

    // projectid => market address
    mapping(uint256 => address) private s_projectToMarketAddr;

    mapping(uint256 => Project) private s_projects;
    // depositor => roundID => deposit
    mapping(address => mapping(uint256 => uint256)) private s_deposits;
    uint256 public constant PROJECT_DEPOSIT = 0.05 ether;
    uint256 public s_projectId;
    mapping(address => uint256[]) private s_projectsByOwner;
    mapping(uint256 => uint256[]) private s_projectsByRound;

    struct Project {
        uint256 projectId;
        address owner;
        string metadataURI;
        uint256 roundId;
    }

    modifier restrictedForEvaluator() {
        require(
            !evaluatorSbt.isEvaluator(msg.sender),
            "Evaluators are restricted from registering projects"
        );
        _;
    }

    modifier onlyProjectOwner(uint256 _projectId) {
        address projectOwner = s_projects[_projectId].owner;
        require(msg.sender == projectOwner, "Not the project's owner");
        _;
    }

    constructor(
        address _roundManager,
        address _evaluatorSbt,
        address _evaluatorGovernor,
        address _timelock
    ) {
        if (
            _roundManager == address(0) ||
            _evaluatorSbt == address(0) ||
            _evaluatorGovernor == address(0) ||
            _timelock == address(0)
        ) {
            revert ProjectRegistry__ZeroAddressNotAllowed();
        }
        roundManager = IRoundManager(_roundManager);
        evaluatorSbt = IEvaluatorSBT(_evaluatorSbt);
        i_evaluatorGovernor = _evaluatorGovernor;
        i_timelock = _timelock;
    }

    function createMarket(uint256 _projectId, uint256 _roundId) internal {
        if (s_projectToMarketAddr[_projectId] != address(0)) {
            revert FundingMarketFactory__MarketAlreadyExists();
        }

        address market = address(
            new FundingMarket(
                _roundId,
                _projectId,
                i_evaluatorGovernor,
                i_timelock,
                address(evaluatorSbt)
            )
        );

        s_projectToMarketAddr[_projectId] = market;
    }

    function registerProject(
        string calldata _metadataURI
    ) external payable restrictedForEvaluator {
        if (bytes(_metadataURI).length == 0) {
            revert ProjectRegistry__InvalidMetadataUri();
        }
        if (msg.value != PROJECT_DEPOSIT) {
            revert ProjectRegistry__InvalidDepositAmount();
        }
        uint256 roundId = roundManager.getCurrentRoundId();
        if (roundId == 0) {
            revert ProjectRegistry__InvalidRoundId();
        }
        if (roundManager.hasRoundEnded(roundId)) {
            revert ProjectRegistry__RoundEnded();
        }

        s_projectId++;
        s_projects[s_projectId] = Project({
            projectId: s_projectId,
            owner: msg.sender,
            metadataURI: _metadataURI,
            roundId: roundId
        });

        s_deposits[msg.sender][roundId] += msg.value;
        s_projectsByOwner[msg.sender].push(s_projectId);
        s_projectsByRound[roundId].push(s_projectId);

        createMarket(s_projectId, roundId);
    }

    function withdrawAllDepositForRound(uint256 _roundId) external {
        if (_roundId == 0) {
            revert ProjectRegistry__InvalidRoundId();
        }
        if (!roundManager.hasRoundEnded(_roundId)) {
            revert ProjectRegistry__RoundOngoing();
        }
        // Total deposit for the round
        uint256 deposit = s_deposits[msg.sender][_roundId];
        if (deposit == 0) {
            revert ProjectRegistry__NoDepositFound();
        }
        if (address(this).balance < deposit) {
            revert ProjectRegistry__NotEnoughBalance();
        }
        s_deposits[msg.sender][_roundId] -= deposit;
        (bool success, ) = payable(msg.sender).call{value: deposit}("");
        if (!success) {
            revert ProjectRegistry__TransferFailed();
        }
    }

    function editMetadataUri(
        uint256 _projectId,
        string calldata _metadataUri
    ) external onlyProjectOwner(_projectId) {
        if (bytes(_metadataUri).length == 0) {
            revert ProjectRegistry__InvalidMetadataUri();
        }
        s_projects[_projectId].metadataURI = _metadataUri;
    }

    function getProject(
        uint256 _projectId
    )
        external
        view
        returns (address owner, string memory metadataURI, uint256 roundId)
    {
        return (
            s_projects[_projectId].owner,
            s_projects[_projectId].metadataURI,
            s_projects[_projectId].roundId
        );
    }

    function getDepositForRound(
        address _user,
        uint256 _roundId
    ) external view returns (uint256) {
        return s_deposits[_user][_roundId];
    }

    function getProjectsByOwner(
        address _owner
    ) external view returns (uint256[] memory) {
        return s_projectsByOwner[_owner];
    }

    function getProjectsForRound(
        uint256 _roundId
    ) external view returns (uint256[] memory) {
        return s_projectsByRound[_roundId];
    }
}
