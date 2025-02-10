// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AIOracle.sol";
import "./HybridChain.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AIIntegration is ReentrancyGuard {
    error OnlyOwner();
    error NoValidValidator();
    error InsufficientRewardBalance();
    error NoAvailableTransactions();
    error InvalidAddress();
    error InvalidAmount();
    
    AIOracle public immutable aiOracle;
    HybridChain public immutable hybridChain;
    address public immutable owner;
    
    uint256 public rewardPool;
    
    event ValidatorPerformanceUpdated(address indexed validator, uint256 successRate);
    event ConsensusExecuted(
        address indexed bestValidator, 
        uint256 indexed transactionId, 
        uint256 rewardAmount, 
        address transactionSender, 
        address transactionReceiver, 
        uint256 transactionAmount
    );
    event RewardPoolReplenished(uint256 amount);

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    constructor(address _aiOracle, address _hybridChain) {
        aiOracle = AIOracle(_aiOracle);
        hybridChain = HybridChain(payable(_hybridChain));
        owner = msg.sender;
        rewardPool = 1000 ether;
    }

    function updateValidatorPerformance(address _validator, uint256 _successRate) external onlyOwner {
        aiOracle.updateValidatorPerformance(_validator, _successRate);
        emit ValidatorPerformanceUpdated(_validator, _successRate);
    }

    function getBestValidator() external view returns (address) {
        return aiOracle.bestValidator();
    }

    function executeConsensus() external onlyOwner {
        address bestValidator = aiOracle.bestValidator();
        if (bestValidator == address(0)) revert NoValidValidator();

        uint256 transactionId = _chooseTransaction();
        HybridChain.Transaction memory transaction = hybridChain.getTransaction(transactionId);

        if (!aiOracle.validateTransaction(
            transaction.sender, 
            transaction.receiver, 
            transaction.amount
        )) revert NoValidValidator();

        hybridChain.confirmTransaction(transactionId);
        uint256 rewardAmount = _distributeRewards(bestValidator);

        emit ConsensusExecuted(
            bestValidator,
            transactionId,
            rewardAmount,
            transaction.sender,
            transaction.receiver,
            transaction.amount
        );
    }

    function _chooseTransaction() internal view returns (uint256) {
        uint256 transactionsLength = hybridChain.getTransactionsLength();
        
        for (uint256 i; i < transactionsLength;) {
            if (!hybridChain.getTransaction(i).isConfirmed) {
                return i;
            }
            unchecked { ++i; }
        }
        
        revert NoAvailableTransactions();
    }

    function _distributeRewards(address _validator) internal nonReentrant returns (uint256) {
        uint256 rewardPercentage = hybridChain.getTransactionFeePercentage();
        uint256 reward = (rewardPool * rewardPercentage) / 100;
        
        if (reward > rewardPool) revert InsufficientRewardBalance();
        
        unchecked {
            rewardPool -= reward;
        }
        
        hybridChain.updateBalance(_validator, reward);
        return reward;
    }

    function replenishRewardPool(uint256 _amount) external onlyOwner {
        unchecked {
            rewardPool += _amount;
        }
        emit RewardPoolReplenished(_amount);
    }

    function validateWithAI(address to, uint256 amount) external pure returns (bool) {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        return true;
    }

    receive() external payable {}
    
    function withdrawRemainingBalance() external onlyOwner {
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }
}