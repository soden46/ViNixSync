// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract AIOracle is AccessControl, Pausable {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    address[] public validatorsList;
    mapping(address => uint256) public validators;
    mapping(address => uint256) public validatorPerformance;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
    }
    
    function registerValidator(address _validator, uint256 _stake) public {
    validators[_validator] = _stake;
    validatorsList.push(_validator);  // Add the validator to the array
}

    function updateValidatorPerformance(address _validator, uint256 _successRate) public {
        validatorPerformance[_validator] = _successRate;
    }

    struct ValidationResult {
        bool isValid;
        uint256 timestamp;
        string reason;
    }

    // Mapping untuk menyimpan hasil validasi
    mapping(bytes32 => ValidationResult) public validations;
    
    // Events
    event TransactionValidated(
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        bool isValid,
        string reason
    );
    event OracleUpdated(address indexed oracle);

    // function selectBestValidator() public view returns (address bestValidator) {
    //     address best;
    //     uint256 highestScore = 0;

    //     for (uint256 i = 0; i < 1000; i++) {
    //         address validator = address(uint160(i));
    //         uint256 score = validatorPerformance[validator];

    //         if (score > highestScore) {
    //             highestScore = score;
    //             best = validator;
    //         }
    //     }

    //     return best;
    // }

    // New function to return the best validator
    function bestValidator() public view returns (address) {
        address best;
        uint256 highestScore = 0;

        // Loop through the array of validators
        for (uint i = 0; i < validatorsList.length; i++) {
            address validator = validatorsList[i];
            uint256 score = validatorPerformance[validator];

            if (score > highestScore) {
                highestScore = score;
                best = validator;
            }
        }

        return best;
    }

    function validateTransaction(address sender, address receiver, uint256 amount) external pure returns (bool) {
        require(sender != address(0), "Invalid sender address");
        require(receiver != address(0), "Invalid receiver address");
        require(amount > 0, "Amount must be greater than 0");

        // AI logic for validation can be placed here
        return true;  // Placeholder
    }

    function recordValidation(
        address sender,
        address receiver,
        uint256 amount,
        bool isValid,
        string memory reason
    ) external onlyRole(ORACLE_ROLE) {
        bytes32 txHash = keccak256(
            abi.encodePacked(sender, receiver, amount, block.timestamp)
        );

        validations[txHash] = ValidationResult({
            isValid: isValid,
            timestamp: block.timestamp,
            reason: reason
        });

        emit TransactionValidated(sender, receiver, amount, isValid, reason);
    }

    // Admin functions
    function addOracle(address oracle) external onlyRole(ADMIN_ROLE) {
        grantRole(ORACLE_ROLE, oracle);
        emit OracleUpdated(oracle);
    }

    function removeOracle(address oracle) external onlyRole(ADMIN_ROLE) {
        revokeRole(ORACLE_ROLE, oracle);
        emit OracleUpdated(oracle);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // View functions
    function getValidation(
        address sender,
        address receiver,
        uint256 amount
    ) external view returns (ValidationResult memory) {
        bytes32 txHash = keccak256(
            abi.encodePacked(sender, receiver, amount, block.timestamp)
        );
        return validations[txHash];
    }
}
