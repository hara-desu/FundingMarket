// TODO:
// Add events

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract EvaluatorSBT is ERC721 {
    // reputation restricted to range 0-100
    mapping(address => uint8) private s_reputations;
    address public immutable i_evaluatorGovernor;
    uint256 private s_tokenId = 1;
    mapping(address => uint256) private s_evaluatorTokenId;
    uint256 private s_evaluatorCount;

    error EvaluatorSBT__TransfersDisabledForSoulbound();
    error EvaluatorSBT__ReputationOutOfRange();
    error EvaluatorSBT__AlreadyEvaluator();
    error EvaluatorSBT__NotEvaluator();
    error EvaluatorSBT__InitialEvaluatorsShouldMatchInitialReputations();
    error EvaluatorSBT__NonexistentToken();
    error EvaluatorSBT__InitialReputationCannotBeZero();
    error EvaluatorSBT__ZeroAddressNotAllowed();

    modifier onlyEvaluatorGovernor() {
        require(msg.sender == i_evaluatorGovernor, "Not the Governor contract");
        _;
    }

    constructor(
        address[] memory _initialEvaluators,
        uint8[] memory _initialReputations,
        address _evaluatorGovernor
    ) ERC721("Evaluator", "EVAL") {
        if (_evaluatorGovernor == address(0)) {
            revert EvaluatorSBT__ZeroAddressNotAllowed();
        }
        i_evaluatorGovernor = _evaluatorGovernor;
        if (_initialEvaluators.length != _initialReputations.length) {
            revert EvaluatorSBT__InitialEvaluatorsShouldMatchInitialReputations();
        }
        for (uint256 i = 0; i < _initialEvaluators.length; i++) {
            address evaluator = _initialEvaluators[i];
            uint8 reputation = _initialReputations[i];
            _mintEvaluator(evaluator, reputation);
        }
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);

        // block normal transfers: only allow mint (from == 0) or burn (to == 0)
        if (from != address(0) && to != address(0)) {
            revert EvaluatorSBT__TransfersDisabledForSoulbound();
        }

        return super._update(to, tokenId, auth);
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) {
            revert EvaluatorSBT__NonexistentToken();
        }
        return
            "ipfs://bafkreihjnxm6dw2t5453ythuh27nip6dkl3vlqrbub6gpu2qry4ckahfoa";
    }

    function mintEvaluator(
        address _to,
        uint8 _reputation
    ) external onlyEvaluatorGovernor {
        _mintEvaluator(_to, _reputation);
    }

    function _mintEvaluator(address _to, uint8 _reputation) internal {
        if (_to == address(0)) {
            revert EvaluatorSBT__ZeroAddressNotAllowed();
        }
        if (s_evaluatorTokenId[_to] != 0) {
            revert EvaluatorSBT__AlreadyEvaluator();
        }
        if (_reputation == 0) {
            revert EvaluatorSBT__InitialReputationCannotBeZero();
        }
        _mint(_to, s_tokenId);
        s_evaluatorTokenId[_to] = s_tokenId;
        s_tokenId++;
        s_evaluatorCount++;
        _adjustReputation(_to, _reputation);
    }

    function adjustReputation(
        address _evaluator,
        uint8 _reputation
    ) external onlyEvaluatorGovernor {
        _adjustReputation(_evaluator, _reputation);
    }

    function _adjustReputation(address _evaluator, uint8 _reputation) internal {
        if (s_evaluatorTokenId[_evaluator] == 0) {
            revert EvaluatorSBT__NotEvaluator();
        }

        if (_reputation > 100) {
            revert EvaluatorSBT__ReputationOutOfRange();
        }

        s_reputations[_evaluator] = _reputation;
    }

    function burnEvaluator(address _evaluator) external onlyEvaluatorGovernor {
        uint256 tokenId = s_evaluatorTokenId[_evaluator];
        if (tokenId == 0) {
            revert EvaluatorSBT__NotEvaluator();
        }
        _adjustReputation(_evaluator, 0);
        delete s_evaluatorTokenId[_evaluator];
        s_evaluatorCount--;
        s_reputations[_evaluator] = 0;
        _burn(tokenId);
    }

    function quitEvaluator() external {
        uint256 tokenId = s_evaluatorTokenId[msg.sender];
        if (tokenId != 0) {
            delete s_evaluatorTokenId[msg.sender];
            _adjustReputation(msg.sender, 0);
            s_evaluatorCount--;
            _burn(tokenId);
        } else {
            revert EvaluatorSBT__NotEvaluator();
        }
    }

    function getReputation(address _evaluator) external view returns (uint8) {
        return s_reputations[_evaluator];
    }

    function isEvaluator(address _address) external view returns (bool) {
        return s_evaluatorTokenId[_address] != 0;
    }

    function getEvaluatorCount() external view returns (uint256) {
        return s_evaluatorCount;
    }

    function getEvaluatorTokenId(
        address _evaluator
    ) external view returns (uint256) {
        return s_evaluatorTokenId[_evaluator];
    }
}
