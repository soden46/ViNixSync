// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract AIOracle is AccessControl, Pausable {
    error InvalidSender();
    error InvalidReceiver();
    error InvalidAmount();
    
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    struct Validator {
        uint256 stake;
        uint256 performance;
        bool exists;
    }
    
    struct ValidationResult {
        bool isValid;
        uint256 timestamp;
        string reason;
    }

    // Immutable storage for frequently accessed values
    address private immutable deployer;
    
    // Consolidated validator data
    mapping(address => Validator) public validators;
    address[] private validatorsList;
    
    // Validation results storage
    mapping(bytes32 => ValidationResult) public validations;
    
    // Events with indexed parameters for efficient filtering
    event TransactionValidated(
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        bool isValid,
        string reason
    );
    event OracleUpdated(address indexed oracle, bool indexed added);
    event ValidatorRegistered(address indexed validator, uint256 stake);
    event ValidatorPerformanceUpdated(address indexed validator, uint256 performance);

    constructor() {
        deployer = msg.sender;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
    }
    
    function registerValidator(address _validator, uint256 _stake) external onlyRole(ADMIN_ROLE) {
        if (!validators[_validator].exists) {
            validators[_validator] = Validator({
                stake: _stake,
                performance: 0,
                exists: true
            });
            validatorsList.push(_validator);
            emit ValidatorRegistered(_validator, _stake);
        } else {
            validators[_validator].stake = _stake;
        }
    }

    function updateValidatorPerformance(address _validator, uint256 _successRate) external onlyRole(ADMIN_ROLE) {
        require(validators[_validator].exists, "Validator not registered");
        validators[_validator].performance = _successRate;
        emit ValidatorPerformanceUpdated(_validator, _successRate);
    }

    function bestValidator() external view returns (address) {
        address best;
        uint256 highestScore;
        uint256 length = validatorsList.length;
        
        for (uint256 i; i < length;) {
            address validator = validatorsList[i];
            uint256 score = validators[validator].performance;
            
            if (score > highestScore) {
                highestScore = score;
                best = validator;
            }
            
            unchecked { ++i; }
        }
        
        return best;
    }

    function validateTransaction(
        address sender,
        address receiver,
        uint256 amount
    ) external view whenNotPaused returns (bool) {
        if (sender == address(0)) revert InvalidSender();
        if (receiver == address(0)) revert InvalidReceiver();
        if (amount == 0) revert InvalidAmount();
        
        // AI validation logic would go here
        return true;
    }

    function recordValidation(
        address sender,
        address receiver,
        uint256 amount,
        bool isValid,
        string calldata reason
    ) external onlyRole(ORACLE_ROLE) whenNotPaused {
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
        emit OracleUpdated(oracle, true);
    }

    function removeOracle(address oracle) external onlyRole(ADMIN_ROLE) {
        revokeRole(ORACLE_ROLE, oracle);
        emit OracleUpdated(oracle, false);
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
        return validations[keccak256(
            abi.encodePacked(sender, receiver, amount, block.timestamp)
        )];
    }
    
    function getValidatorsList() external view returns (address[] memory) {
        return validatorsList;
    }
}