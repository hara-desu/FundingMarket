interface IEvaluatorSBT {
    function isEvaluator(address _address) external view returns (bool);
}

interface IRoundManager {
    function getCurrentRoundId() external view returns (uint256);

    function hasRoundEnded(uint256 roundId) external view returns (bool);
}
