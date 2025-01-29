// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./AIOracle.sol";

contract AIIntegration {
    AIOracle public aiOracle;

    constructor(address _aiOracle) {
        aiOracle = AIOracle(_aiOracle);
    }

    function executeConsensus() public {
        aiOracle.selectBestValidator();
    }

    function getBestValidator() public view returns (address) {
        return aiOracle.bestValidator();
    }
}
