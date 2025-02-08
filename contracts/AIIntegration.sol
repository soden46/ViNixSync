// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AIOracle.sol";
import "./HybridChain.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AIIntegration is ReentrancyGuard {
    AIOracle public aiOracle;
    HybridChain public hybridChain;

    address public owner;
    uint256 public rewardPool; // Reward pool awal

    // Event yang lebih spesifik
    event ValidatorRegistered(address validator, uint256 stake);
    event ValidatorPerformanceUpdated(address validator, uint256 successRate);
    event ConsensusExecuted(address bestValidator, uint256 transactionId, uint256 rewardAmount, address indexed transactionSender, address indexed transactionReceiver, uint256 transactionAmount);
    event RewardPoolReplenished(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    constructor(address _aiOracle, address _hybridChain) {
        aiOracle = AIOracle(_aiOracle);
        hybridChain = HybridChain(payable(_hybridChain));
        owner = msg.sender;
        rewardPool = 1000 ether;
    }

    function updateValidatorPerformance(address _validator, uint256 _successRate) public onlyOwner {
        aiOracle.updateValidatorPerformance(_validator, _successRate);

        emit ValidatorPerformanceUpdated(_validator, _successRate);
    }

    function getBestValidator() public view returns (address) {
        return aiOracle.bestValidator();
    }

    function executeConsensus() public onlyOwner {
        address bestValidator = aiOracle.bestValidator();
        require(bestValidator != address(0), "No valid validator available");

        uint256 transactionId = _chooseTransaction();
        HybridChain.Transaction memory transaction = hybridChain.getTransaction(transactionId);

        // Validate transaction with AI Oracle
        require(aiOracle.validateTransaction(transaction.sender, transaction.receiver, transaction.amount), "AI validation failed");

        hybridChain.confirmTransaction(transactionId);
        uint256 rewardAmount = _distributeRewards(bestValidator);

        emit ConsensusExecuted(bestValidator, transactionId, rewardAmount, transaction.sender, transaction.receiver, transaction.amount);
    }

    function _chooseTransaction() internal view returns (uint256) {
        uint256 transactionsLength = hybridChain.getTransactionsLength();

        for (uint256 i = 0; i < transactionsLength; i++) {
            HybridChain.Transaction memory transaction = hybridChain.getTransaction(i);
            if (!transaction.isConfirmed) {
                return i;
            }
        }

        revert("No transactions available to confirm");
    }

    function _distributeRewards(address _validator) internal nonReentrant returns (uint256) {
        uint256 rewardPercentage = hybridChain.getTransactionFeePercentage();
        uint256 reward = (rewardPool * rewardPercentage) / 100; // Operasi aritmatika langsung (aman di 0.8+)

        require(reward <= rewardPool, "Insufficient reward pool balance");

        rewardPool -= reward; // Pengurangan langsung (aman di 0.8+)
        hybridChain.updateBalance(_validator, reward);

        return reward;
    }

    function replenishRewardPool(uint256 _amount) public onlyOwner {
        rewardPool += _amount; // Penambahan langsung (aman di 0.8+)
        emit RewardPoolReplenished(_amount);
    }

    function validateWithAI(address to, uint256 amount) public pure returns (bool) {
        require(to != address(0), "Invalid address");
        require(amount > 0, "Amount must be greater than 0");
        return true;
    }
    // Fungsi untuk menarik sisa dana di kontrak AIIntegration (gunakan dengan hati-hati)
    function withdrawRemainingBalance() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

}