// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {IEvaluatorSBT, IRoundManager, IProjectRegistry} from "@src/Interfaces.sol";
import {FundingMarket} from "@src/market/FundingMarket.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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

contract ProjectRegistry is IProjectRegistry, ReentrancyGuard {
    struct Project {
        uint256 projectId;
        address owner;
        string metadataURI;
        uint256 roundId;
    }

    IRoundManager private immutable i_roundManager;
    IEvaluatorSBT private immutable i_evaluatorSbt;
    address private immutable i_evaluatorGovernor;
    address private immutable i_timelock;

    uint256 private constant PROJECT_DEPOSIT = 0.05 ether;

    uint256 private s_projectId;

    // projectid => market address
    mapping(uint256 => address) private s_projectToMarketAddr;
    mapping(uint256 => Project) private s_projects;
    // depositor => roundID => deposit
    mapping(address => mapping(uint256 => uint256)) private s_deposits;
    mapping(address => uint256[]) private s_projectsByOwner;
    mapping(uint256 => uint256[]) private s_projectsByRound;

    event ProjectRegisteredAndMarketCreated(
        uint256 indexed roundId,
        uint256 indexed projectId
    );
    event DepositWithdrawn(
        uint256 indexed roundId,
        address indexed recepient,
        uint256 amount
    );
    event MetadataEdited(uint256 indexed projectId, string metadataUri);

    modifier restrictedForEvaluator() {
        require(
            !i_evaluatorSbt.isEvaluator(msg.sender),
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
        i_roundManager = IRoundManager(_roundManager);
        i_evaluatorSbt = IEvaluatorSBT(_evaluatorSbt);
        i_evaluatorGovernor = _evaluatorGovernor;
        i_timelock = _timelock;
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
        uint256 roundId = i_roundManager.getCurrentRoundId();
        if (roundId == 0) {
            revert ProjectRegistry__InvalidRoundId();
        }
        if (i_roundManager.hasRoundEnded(roundId)) {
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

        emit ProjectRegisteredAndMarketCreated(roundId, s_projectId);
    }

    function withdrawAllDepositForRound(
        uint256 _roundId
    ) external nonReentrant {
        if (_roundId == 0) {
            revert ProjectRegistry__InvalidRoundId();
        }
        if (!i_roundManager.hasRoundEnded(_roundId)) {
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

        emit DepositWithdrawn(_roundId, msg.sender, deposit);
    }

    function editMetadataUri(
        uint256 _projectId,
        string calldata _metadataUri
    ) external onlyProjectOwner(_projectId) {
        if (bytes(_metadataUri).length == 0) {
            revert ProjectRegistry__InvalidMetadataUri();
        }
        s_projects[_projectId].metadataURI = _metadataUri;

        emit MetadataEdited(_projectId, _metadataUri);
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
                address(i_evaluatorSbt)
            )
        );

        s_projectToMarketAddr[_projectId] = market;
    }

    //----------------- Getter Functions -----------------//

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

    function getMarketForProject(
        uint256 _projectId
    ) external view returns (address) {
        return s_projectToMarketAddr[_projectId];
    }

    function getProjectCount() external view returns (uint256) {
        return s_projectId;
    }

    function getProjectDepositAmount() external pure returns (uint256) {
        return PROJECT_DEPOSIT;
    }

    receive() external payable {
        revert("Do not send ETH directly");
    }

    fallback() external payable {
        revert("Invalid call");
    }
}
