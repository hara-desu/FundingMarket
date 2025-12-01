interface IEvaluatorSBT {
    function isEvaluator(address _address) external view returns (bool);

    function getEvaluatorCount() external view returns (uint256);
}

interface IRoundManager {
    function getCurrentRoundId() external view returns (uint256);

    function hasRoundEnded(uint256 roundId) external view returns (bool);
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
}

interface IFundingMarket {
    function getMarketScore(uint256 _projectId) external view returns (uint256);
}
