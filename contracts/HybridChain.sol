// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AIOracle.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title HybridChain
 * @dev Advanced blockchain implementation with AI integration and improved fee structure
 */
contract HybridChain is ReentrancyGuard, Pausable, AccessControl {
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    struct Transaction {
        address sender;
        address receiver;
        uint256 amount;
        uint256 timestamp;
        bool isConfirmed;
        FeeStructure fees;
        ValidationStatus status;
    }

    struct Validator {
        uint256 stake;
        uint256 successRate;
        uint256 totalValidated;
        uint256 reputationScore;
        bool isActive;
        uint256 lastValidationTime;
    }

    struct FeeStructure {
        uint256 baseFee;
        uint256 validatorFee;
        uint256 networkFee;
        uint256 aiProcessingFee;
    }

    enum ValidationStatus {
        Pending,
        Confirmed,
        Rejected
    }

    // State variables
    AIOracle public immutable aiOracle;
    mapping(address => uint256) public balances;
    mapping(address => Validator) public validators;
    address[] private validatorList;
    Transaction[] private transactions;
    
    // Fee configuration
    uint256 public baseTransactionFee;
    uint256 public validatorFeePercentage;
    uint256 public networkFeePercentage;
    uint256 public aiProcessingFeePercentage;
    uint256 public minimumStake;
    
    // Constants
    uint256 private constant MAX_FEE_PERCENTAGE = 1000; // 10% in basis points
    uint256 private constant BASIS_POINTS = 10000;
    
    // Events
    event TransactionCreated(uint256 indexed transactionId, address indexed sender, address indexed receiver, uint256 amount);
    event TransactionConfirmed(uint256 indexed transactionId, address indexed validator);
    event TransactionRejected(uint256 indexed transactionId, address indexed validator, string reason);
    event ValidatorRegistered(address indexed validator, uint256 stake);
    event ValidatorDeregistered(address indexed validator);
    event FeeUpdated(string feeType, uint256 newValue);
    event ValidatorRewardDistributed(address indexed validator, uint256 amount);
    event BalanceUpdated(address indexed validator, uint256 newBalance);

    constructor(address _aiOracle, uint256 _baseTransactionFee, uint256 _minimumStake) {
    require(_aiOracle != address(0), "Invalid AI Oracle address");
    
        aiOracle = AIOracle(_aiOracle);
        baseTransactionFee = _baseTransactionFee;
        minimumStake = _minimumStake;

        // Initialize fee percentages (in basis points)
        validatorFeePercentage = 500;    // 5%
        networkFeePercentage = 200;      // 2%
        aiProcessingFeePercentage = 100; // 1%

        grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        grantRole(FEE_MANAGER_ROLE, msg.sender);
    }

    function getTransactionsLength() public view returns (uint256) {
        return transactions.length;
    }

    // Fee calculation functions
    function calculateFees(uint256 amount) public view returns (FeeStructure memory) {
        return FeeStructure({
            baseFee: baseTransactionFee,
            validatorFee: (amount * validatorFeePercentage) / BASIS_POINTS,
            networkFee: (amount * networkFeePercentage) / BASIS_POINTS,
            aiProcessingFee: (amount * aiProcessingFeePercentage) / BASIS_POINTS
        });
    }

    function getTotalFees(FeeStructure memory fees) public pure returns (uint256) {
        return fees.baseFee + fees.validatorFee + fees.networkFee + fees.aiProcessingFee;
    }

    // Transaction functions
    function createTransaction(address receiver) public payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Amount must be greater than zero");
        require(receiver != address(0), "Invalid receiver address");
        
        FeeStructure memory fees = calculateFees(msg.value);
        uint256 totalFees = getTotalFees(fees);
        require(msg.value > totalFees, "Amount must be greater than fees");

        uint256 transactionId = transactions.length;
        transactions.push(Transaction({
            sender: msg.sender,
            receiver: receiver,
            amount: msg.value - totalFees,
            timestamp: block.timestamp,
            isConfirmed: false,
            fees: fees,
            status: ValidationStatus.Pending
        }));

        emit TransactionCreated(transactionId, msg.sender, receiver, msg.value);
    }

    function confirmTransaction(uint256 transactionId) public nonReentrant onlyRole(VALIDATOR_ROLE) {
        require(transactionId < transactions.length, "Invalid transaction ID");
        Transaction storage transaction = transactions[transactionId];
        require(transaction.status == ValidationStatus.Pending, "Invalid transaction status");
        require(validators[msg.sender].isActive, "Validator not active");

        // AI Oracle validation check
        require(aiOracle.validateTransaction(
                transaction.sender,
                transaction.receiver,
                transaction.amount
            ),
            "AI Oracle rejected transaction"
        );

        // Update transaction status
        transaction.status = ValidationStatus.Confirmed;
        transaction.isConfirmed = true;

        // Distribute fees
        _distributeTransactionFees(transaction);
        
        // Update validator metrics
        _updateValidatorMetrics(msg.sender, true);

        emit TransactionConfirmed(transactionId, msg.sender);
    }

    // Validator management functions
    function registerValidator() public payable nonReentrant {
        require(msg.value >= minimumStake, "Insufficient stake");
        require(!validators[msg.sender].isActive, "Already registered");

        validators[msg.sender] = Validator({
            stake: msg.value,
            successRate: 100,
            totalValidated: 0,
            reputationScore: 100,
            isActive: true,
            lastValidationTime: block.timestamp
        });

        validatorList.push(msg.sender);
        grantRole(VALIDATOR_ROLE, msg.sender);

        emit ValidatorRegistered(msg.sender, msg.value);
    }

    // Internal utility functions
    function _distributeTransactionFees(Transaction storage transaction) private {
        FeeStructure memory fees = transaction.fees;
        
        // Transfer amount to receiver
        (bool success, ) = transaction.receiver.call{value: transaction.amount}("");
        require(success, "Transfer to receiver failed");

        // Distribute validator fee
        (success, ) = msg.sender.call{value: fees.validatorFee}("");
        require(success, "Validator fee transfer failed");

        // Network and AI processing fees are kept in contract
    }

    function _updateValidatorMetrics(address validator, bool successful) private {
        Validator storage v = validators[validator];
        v.totalValidated++;
        
        if (successful) {
            v.successRate = ((v.successRate * (v.totalValidated - 1)) + 100) / v.totalValidated;
            v.reputationScore = Math.min(v.reputationScore + 1, 100);
        } else {
            v.successRate = ((v.successRate * (v.totalValidated - 1))) / v.totalValidated;
            v.reputationScore = Math.max(v.reputationScore - 1, 0);
        }
        
        v.lastValidationTime = block.timestamp;
    }

    // View functions
    function getTransaction(uint256 _index) public view returns (Transaction memory) {
        require(_index < transactions.length, "Index out of bounds");
        return transactions[_index];
    }

    function getValidatorData(address _validator) public view returns (Validator memory) {
        return validators[_validator];
    }

    function getActiveValidators() public view returns (address[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < validatorList.length; i++) {
            if (validators[validatorList[i]].isActive) {
                activeCount++;
            }
        }

        address[] memory activeValidators = new address[](activeCount);
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < validatorList.length; i++) {
            if (validators[validatorList[i]].isActive) {
                activeValidators[currentIndex] = validatorList[i];
                currentIndex++;
            }
        }

        return activeValidators;
    }

    // Admin functions
    function updateFeePercentage(
        string memory feeType,
        uint256 newPercentage
    ) public onlyRole(FEE_MANAGER_ROLE) {
        require(newPercentage <= MAX_FEE_PERCENTAGE, "Fee percentage too high");
        
        bytes32 feeTypeHash = keccak256(abi.encodePacked(feeType));
        if (feeTypeHash == keccak256("validator")) {
            validatorFeePercentage = newPercentage;
        } else if (feeTypeHash == keccak256("network")) {
            networkFeePercentage = newPercentage;
        } else if (feeTypeHash == keccak256("ai")) {
            aiProcessingFeePercentage = newPercentage;
        } else {
            revert("Invalid fee type");
        }

        emit FeeUpdated(feeType, newPercentage);
    }

    function getTransactionFeePercentage() public view returns (uint256) {
        return validatorFeePercentage;
    }

    function updateBalance(address _validator, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant 
    {
        require(_validator != address(0), "Invalid validator address");
        require(_amount > 0, "Amount must be greater than zero");

        balances[_validator] += _amount;

        emit BalanceUpdated(_validator, balances[_validator]);
    }
    
    // Fallback and receive functions
    receive() external payable {}
    fallback() external payable {}
}
