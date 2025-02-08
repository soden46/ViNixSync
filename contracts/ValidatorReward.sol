// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./HybridChain.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title ValidatorReward
 * @dev Enhanced reward system for hybrid consensus validators incorporating AI metrics
 */
contract ValidatorReward is ReentrancyGuard, Pausable, AccessControl {
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant AI_ORACLE_ROLE = keccak256("AI_ORACLE_ROLE");
    
    HybridChain public immutable hybridChain;
    
    // Enhanced reward configuration
    struct RewardParameters {
        uint256 baseRewardPerValidation;
        uint256 reputationMultiplier;
        uint256 powBonusMultiplier;     // Bonus for PoW contribution
        uint256 pohBonusMultiplier;     // Bonus for PoH performance
        uint256 aiPerformanceMultiplier; // Bonus for AI validation accuracy
        uint256 minimumReputationScore;
        uint256 minimumAIAccuracyScore;
        uint256 distributionCooldown;
    }
    
    RewardParameters public rewardParams;
    uint256 public lastDistributionTime;
    
    // Performance tracking
    struct ValidatorPerformance {
        uint256 powHashrate;      // PoW contribution metric
        uint256 pohLatency;       // PoH performance metric
        uint256 aiAccuracyScore;  // AI validation accuracy
        uint256 lastUpdateTime;
    }
    
    // Enhanced reward tracking
    mapping(address => uint256) public pendingRewards;
    mapping(address => uint256) public totalRewardsDistributed;
    mapping(address => uint256) public lastClaimTime;
    mapping(address => ValidatorPerformance) public validatorPerformance;
    
    // Network statistics
    uint256 public totalRewardsDistributedAllTime;
    uint256 public totalValidationsRewarded;
    uint256 public averageAIAccuracyScore;
    
    // Events
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
        require(_hybridChain != address(0), "Invalid HybridChain address");
        require(_baseRewardPerValidation > 0, "Invalid base reward");
        require(_minimumReputationScore <= 100, "Invalid reputation score");
        require(_minimumAIAccuracyScore <= 100, "Invalid AI accuracy score");
        
        hybridChain = HybridChain(payable(_hybridChain));
        
        // Initialize reward parameters
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
        require(validator != address(0), "Invalid validator address");
        require(aiAccuracyScore <= 100, "Invalid AI accuracy score");
        
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
        
        require(validatorData.isActive, "Validator not active");
        require(validatorData.reputationScore >= rewardParams.minimumReputationScore, "Reputation too low");
        require(performance.aiAccuracyScore >= rewardParams.minimumAIAccuracyScore, "AI accuracy too low");
        
        // Calculate base reward
        uint256 reward = validationCount * rewardParams.baseRewardPerValidation;
        
        // Apply reputation multiplier
        reward = reward * validatorData.reputationScore * rewardParams.reputationMultiplier / 10000;
        
        // Apply PoW bonus
        if (performance.powHashrate > 0) {
            reward = reward * (100 + rewardParams.powBonusMultiplier) / 100;
        }
        
        // Apply PoH bonus (lower latency = higher bonus)
        if (performance.pohLatency > 0) {
            uint256 pohBonus = (1000 / performance.pohLatency) * rewardParams.pohBonusMultiplier;
            reward = reward * (100 + pohBonus) / 100;
        }
        
        // Apply AI performance bonus
        uint256 aiBonus = performance.aiAccuracyScore * rewardParams.aiPerformanceMultiplier / 100;
        reward = reward * (100 + aiBonus) / 100;
        
        return reward;
    }
    
    function distributeRewards() external nonReentrant whenNotPaused onlyRole(DISTRIBUTOR_ROLE) {
        require(block.timestamp >= lastDistributionTime + rewardParams.distributionCooldown, "Distribution cooldown not met");

        address[] memory validators = hybridChain.getActiveValidators();
        require(validators.length > 0, "No active validators");

        for (uint256 i = 0; i < validators.length; i++) {
            address validator = validators[i];
            try this.distributeValidatorReward(validator) {
                // Reward distributed successfully
            } catch Error(string memory reason) {
                emit DistributionFailed(validator, reason);
            }
        }

        lastDistributionTime = block.timestamp;
    }
    
    function distributeValidatorReward(address validator) external onlyRole(DISTRIBUTOR_ROLE) {
        HybridChain.Validator memory validatorData = hybridChain.getValidatorData(validator);
        uint256 reward = calculateReward(validator, validatorData.totalValidated);
        
        if (reward > 0) {
            pendingRewards[validator] += reward;
            totalValidationsRewarded += validatorData.totalValidated;
            
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
        require(reward > 0, "No rewards to claim");
        
        pendingRewards[msg.sender] = 0;
        totalRewardsDistributed[msg.sender] += reward;
        totalRewardsDistributedAllTime += reward;
        lastClaimTime[msg.sender] = block.timestamp;
        
        (bool success, ) = msg.sender.call{value: reward}("");
        require(success, "Reward transfer failed");
        
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
        require(_baseRewardPerValidation > 0, "Invalid base reward");
        require(_minimumReputationScore <= 100, "Invalid reputation score");
        require(_minimumAIAccuracyScore <= 100, "Invalid AI accuracy score");
        
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
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    function getValidatorStats(address validator) external view returns (
        uint256 pendingReward,
        uint256 totalRewarded,
        uint256 lastClaim,
        ValidatorPerformance memory performance
    ) {
        return (
            pendingRewards[validator],
            totalRewardsDistributed[validator],
            lastClaimTime[validator],
            validatorPerformance[validator]
        );
    }
    
    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(paused(), "Contract must be paused");
        require(block.timestamp > lastDistributionTime + 7 days, "Cooldown period not met");
        
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        
        payable(msg.sender).transfer(balance);
    }
    
    receive() external payable {}
}