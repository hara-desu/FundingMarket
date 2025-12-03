interface IEvaluatorSBT {
    function isEvaluator(address _address) external view returns (bool);

    function getEvaluatorCount() external view returns (uint256);
}

interface IRoundManager {
    function getCurrentRoundId() external view returns (uint256);

    function hasRoundEnded(uint256 roundId) external view returns (bool);

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
        );
}

interface IProjectRegistry {
    function getProjectsForRound(
        uint256 _roundId
    ) external view returns (uint256[] memory);

    function getProject(
        uint256 _projectId
    )
        external
        view
        returns (address owner, string memory metadataURI, uint256 roundId);

    function getMarketForProject(
        uint256 _projectId
    ) external view returns (address);
}

interface IEvaluatorGovernor {
    function getImpactScoreForProject(
        uint256 _roundId,
        uint256 _projectId
    ) external view returns (uint256);

    function proposeImpactEval(
        uint256 _roundId,
        uint256 _projectId,
        uint256 _votingPeriod
    ) external returns (uint256);

    function executeImpactProposal(uint256 _proposalId) external;

    function getImpactProposalIdForProject(
        uint256 roundId,
        uint256 projectId
    ) external view returns (uint256);
}

interface IFundingMarket {
    function getMarketScore(uint256 _projectId) external view returns (uint256);
}
