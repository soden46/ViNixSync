// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AIOracle {
    struct Validator {
        address validatorAddress;
        uint256 stake;
        uint256 successRate;
        uint256 totalValidated;
    }

    mapping(address => Validator) public validators;
    address[] public validatorList;
    address public bestValidator;

    event ValidatorUpdated(address validator, uint256 newSuccessRate);
    event BestValidatorSelected(address bestValidator);

    function registerValidator(uint256 stake) public {
        require(stake > 0, "Stake must be greater than zero");
        require(validators[msg.sender].stake == 0, "Validator already registered");

        validators[msg.sender] = Validator(msg.sender, stake, 100, 0);
        validatorList.push(msg.sender);
    }

    function updateValidatorPerformance(address validator, uint256 successRate) public {
        require(validators[validator].stake > 0, "Validator not registered");
        validators[validator].successRate = successRate;

        emit ValidatorUpdated(validator, successRate);
    }

    function selectBestValidator() public {
        uint256 highestScore = 0;
        address selectedValidator;

        for (uint256 i = 0; i < validatorList.length; i++) {
            address validator = validatorList[i];
            uint256 score = (validators[validator].stake * 2) + validators[validator].successRate;
            
            if (score > highestScore) {
                highestScore = score;
                selectedValidator = validator;
            }
        }

        bestValidator = selectedValidator;
        emit BestValidatorSelected(bestValidator);
    }
}
