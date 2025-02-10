// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./HybridChain.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract ValidatorReward is ReentrancyGuard, Pausable, AccessControl {
    error InvalidAddress();
    error InvalidBaseReward();
    error InvalidScore();
    error CooldownNotMet();
    error NoActiveValidators();
    error ValidatorNotActive();
    error ReputationTooLow();
    error AIAccuracyTooLow();
    error NoRewardsToClaim();
    error TransferFailed();
    error EmergencyConditionsNotMet();
    error NoBalance();
    
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant AI_ORACLE_ROLE = keccak256("AI_ORACLE_ROLE");
    uint256 private constant PERCENTAGE_BASE = 100;
    uint256 private constant MAX_SCORE = 100;
    uint256 private constant REPUTATION_BASE = 10000;
    uint256 private constant EMERGENCY_COOLDOWN = 7 days;
    
    struct RewardParameters {
        uint256 baseRewardPerValidation;
        uint256 reputationMultiplier;
        uint256 powBonusMultiplier;
        uint256 pohBonusMultiplier;
        uint256 aiPerformanceMultiplier;
        uint256 minimumReputationScore;
        uint256 minimumAIAccuracyScore;
        uint256 distributionCooldown;
    }
    
    struct ValidatorPerformance {
        uint256 powHashrate;
        uint256 pohLatency;
        uint256 aiAccuracyScore;
        uint256 lastUpdateTime;
    }
    
    HybridChain public immutable hybridChain;
    
    RewardParameters public rewardParams;
    uint256 public lastDistributionTime;
    uint256 public totalRewardsDistributedAllTime;
    uint256 public totalValidationsRewarded;
    
    mapping(address => uint256) public pendingRewards;
    mapping(address => uint256) public totalRewardsDistributed;
    mapping(address => uint256) public lastClaimTime;
    mapping(address => ValidatorPerformance) public validatorPerformance;
    
    event RewardDistributed(
        address indexed validator,
        uint256 amount,
        uint256 validationCount,
        uint256 aiAccuracyBonus
    );
    event RewardsClaimed(address indexed validator, uint256 amount);
    event PerformanceUpdated(
        address indexed validator,
        uint256 powHashrate,
        uint256 pohLatency,
        uint256 aiAccuracyScore
    );
    event RewardParametersUpdated(RewardParameters params);
    event DistributionFailed(address indexed validator, string reason);

    constructor(
        address _hybridChain,
        uint256 _baseRewardPerValidation,
        uint256 _reputationMultiplier,
        uint256 _powBonusMultiplier,
        uint256 _pohBonusMultiplier,
        uint256 _aiPerformanceMultiplier,
        uint256 _minimumReputationScore,
        uint256 _minimumAIAccuracyScore,
        uint256 _distributionCooldown
    ) {
        if (_hybridChain == address(0)) revert InvalidAddress();
        if (_baseRewardPerValidation == 0) revert InvalidBaseReward();
        if (_minimumReputationScore > MAX_SCORE) revert InvalidScore();
        if (_minimumAIAccuracyScore > MAX_SCORE) revert InvalidScore();
        
        hybridChain = HybridChain(payable(_hybridChain));
        
        rewardParams = RewardParameters({
            baseRewardPerValidation: _baseRewardPerValidation,
            reputationMultiplier: _reputationMultiplier,
            powBonusMultiplier: _powBonusMultiplier,
            pohBonusMultiplier: _pohBonusMultiplier,
            aiPerformanceMultiplier: _aiPerformanceMultiplier,
            minimumReputationScore: _minimumReputationScore,
            minimumAIAccuracyScore: _minimumAIAccuracyScore,
            distributionCooldown: _distributionCooldown
        });
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
        _grantRole(AI_ORACLE_ROLE, msg.sender);
    }
    
    function updateValidatorPerformance(
        address validator,
        uint256 powHashrate,
        uint256 pohLatency,
        uint256 aiAccuracyScore
    ) external onlyRole(AI_ORACLE_ROLE) {
        if (validator == address(0)) revert InvalidAddress();
        if (aiAccuracyScore > MAX_SCORE) revert InvalidScore();
        
        ValidatorPerformance storage performance = validatorPerformance[validator];
        performance.powHashrate = powHashrate;
        performance.pohLatency = pohLatency;
        performance.aiAccuracyScore = aiAccuracyScore;
        performance.lastUpdateTime = block.timestamp;
        
        emit PerformanceUpdated(validator, powHashrate, pohLatency, aiAccuracyScore);
    }
    
    function calculateReward(
        address validator,
        uint256 validationCount
    ) public view returns (uint256) {
        ValidatorPerformance memory performance = validatorPerformance[validator];
        HybridChain.Validator memory validatorData = hybridChain.getValidatorData(validator);
        
        if (!validatorData.isActive) revert ValidatorNotActive();
        if (validatorData.reputationScore < rewardParams.minimumReputationScore) revert ReputationTooLow();
        if (performance.aiAccuracyScore < rewardParams.minimumAIAccuracyScore) revert AIAccuracyTooLow();
        
        uint256 reward;
        unchecked {
            reward = validationCount * rewardParams.baseRewardPerValidation;
            
            reward = reward * validatorData.reputationScore * rewardParams.reputationMultiplier / REPUTATION_BASE;
            
            if (performance.powHashrate > 0) {
                reward = reward * (PERCENTAGE_BASE + rewardParams.powBonusMultiplier) / PERCENTAGE_BASE;
            }
            
            if (performance.pohLatency > 0) {
                uint256 pohBonus = (1000 / performance.pohLatency) * rewardParams.pohBonusMultiplier;
                reward = reward * (PERCENTAGE_BASE + pohBonus) / PERCENTAGE_BASE;
            }
            
            uint256 aiBonus = performance.aiAccuracyScore * rewardParams.aiPerformanceMultiplier / PERCENTAGE_BASE;
            reward = reward * (PERCENTAGE_BASE + aiBonus) / PERCENTAGE_BASE;
        }
        
        return reward;
    }
    
    function distributeRewards() external nonReentrant whenNotPaused onlyRole(DISTRIBUTOR_ROLE) {
        if (block.timestamp < lastDistributionTime + rewardParams.distributionCooldown) revert CooldownNotMet();

        address[] memory validators = hybridChain.getActiveValidators();
        if (validators.length == 0) revert NoActiveValidators();

        for (uint256 i; i < validators.length;) {
            try this.distributeValidatorReward(validators[i]) {
            } catch Error(string memory reason) {
                emit DistributionFailed(validators[i], reason);
            }
            unchecked { ++i; }
        }

        lastDistributionTime = block.timestamp;
    }
    
    function distributeValidatorReward(address validator) external onlyRole(DISTRIBUTOR_ROLE) {
        HybridChain.Validator memory validatorData = hybridChain.getValidatorData(validator);
        uint256 reward = calculateReward(validator, validatorData.totalValidated);
        
        if (reward > 0) {
            unchecked {
                pendingRewards[validator] += reward;
                totalValidationsRewarded += validatorData.totalValidated;
            }
            
            emit RewardDistributed(
                validator,
                reward,
                validatorData.totalValidated,
                validatorPerformance[validator].aiAccuracyScore
            );
        }
    }
    
    function claimRewards() external nonReentrant whenNotPaused {
        uint256 reward = pendingRewards[msg.sender];
        if (reward == 0) revert NoRewardsToClaim();
        
        pendingRewards[msg.sender] = 0;
        unchecked {
            totalRewardsDistributed[msg.sender] += reward;
            totalRewardsDistributedAllTime += reward;
        }
        lastClaimTime[msg.sender] = block.timestamp;
        
        (bool success, ) = msg.sender.call{value: reward}("");
        if (!success) revert TransferFailed();
        
        emit RewardsClaimed(msg.sender, reward);
    }
    
    function updateRewardParameters(
        uint256 _baseRewardPerValidation,
        uint256 _reputationMultiplier,
        uint256 _powBonusMultiplier,
        uint256 _pohBonusMultiplier,
        uint256 _aiPerformanceMultiplier,
        uint256 _minimumReputationScore,
        uint256 _minimumAIAccuracyScore,
        uint256 _distributionCooldown
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_baseRewardPerValidation == 0) revert InvalidBaseReward();
        if (_minimumReputationScore > MAX_SCORE) revert InvalidScore();
        if (_minimumAIAccuracyScore > MAX_SCORE) revert InvalidScore();
        
        rewardParams = RewardParameters({
            baseRewardPerValidation: _baseRewardPerValidation,
            reputationMultiplier: _reputationMultiplier,
            powBonusMultiplier: _powBonusMultiplier,
            pohBonusMultiplier: _pohBonusMultiplier,
            aiPerformanceMultiplier: _aiPerformanceMultiplier,
            minimumReputationScore: _minimumReputationScore,
            minimumAIAccuracyScore: _minimumAIAccuracyScore,
            distributionCooldown: _distributionCooldown
        });
        
        emit RewardParametersUpdated(rewardParams);
    }
    
    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!paused()) revert EmergencyConditionsNotMet();
        if (block.timestamp <= lastDistributionTime + EMERGENCY_COOLDOWN) revert CooldownNotMet();
        
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoBalance();
        
        (bool success, ) = msg.sender.call{value: balance}("");
        if (!success) revert TransferFailed();
    }
    
    receive() external payable {}
}