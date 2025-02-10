// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AIOracle.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract HybridChain is ReentrancyGuard, Pausable, AccessControl {
    error InvalidAddress();
    error InsufficientAmount();
    error InsufficientStake();
    error AlreadyRegistered();
    error InvalidTransaction();
    error InvalidValidator();
    error TransferFailed();
    error InvalidFeeType();
    error FeeTooHigh();
    
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
    uint256 private constant MAX_FEE_PERCENTAGE = 1000; // 10% in basis points
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant MAX_REPUTATION = 100;

    enum ValidationStatus { Pending, Confirmed, Rejected }

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

    // Immutable state variables
    AIOracle public immutable aiOracle;
    uint256 public immutable minimumStake;
    
    // State variables
    mapping(address => uint256) public balances;
    mapping(address => Validator) public validators;
    address[] private validatorList;
    Transaction[] private transactions;
    
    uint256 public baseTransactionFee;
    uint256 public validatorFeePercentage;
    uint256 public networkFeePercentage;
    uint256 public aiProcessingFeePercentage;
    
    // Events with indexed parameters
    event TransactionCreated(uint256 indexed transactionId, address indexed sender, address indexed receiver, uint256 amount);
    event TransactionConfirmed(uint256 indexed transactionId, address indexed validator);
    event ValidatorRegistered(address indexed validator, uint256 stake);
    event FeeUpdated(string indexed feeType, uint256 newValue);
    event BalanceUpdated(address indexed validator, uint256 newBalance);

    constructor(address _aiOracle, uint256 _baseTransactionFee, uint256 _minimumStake) {
        if (_aiOracle == address(0)) revert InvalidAddress();
        
        aiOracle = AIOracle(_aiOracle);
        baseTransactionFee = _baseTransactionFee;
        minimumStake = _minimumStake;
        
        validatorFeePercentage = 500;    // 5%
        networkFeePercentage = 200;      // 2%
        aiProcessingFeePercentage = 100; // 1%

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(FEE_MANAGER_ROLE, msg.sender);
    }

    function getTotalFees(FeeStructure memory fees) public pure returns (uint256) {
        return fees.baseFee + fees.validatorFee + fees.networkFee + fees.aiProcessingFee;
    }

    function createTransaction(address receiver) external payable nonReentrant whenNotPaused {
        if (msg.value == 0) revert InsufficientAmount();
        if (receiver == address(0)) revert InvalidAddress();
        
        FeeStructure memory fees = calculateFees(msg.value);
        uint256 totalFees = getTotalFees(fees);
        if (msg.value <= totalFees) revert InsufficientAmount();

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

    function confirmTransaction(uint256 transactionId) external nonReentrant onlyRole(VALIDATOR_ROLE) {
        if (transactionId >= transactions.length) revert InvalidTransaction();
        Transaction storage transaction = transactions[transactionId];
        if (transaction.status != ValidationStatus.Pending) revert InvalidTransaction();
        if (!validators[msg.sender].isActive) revert InvalidValidator();

        if (!aiOracle.validateTransaction(
            transaction.sender,
            transaction.receiver,
            transaction.amount
        )) revert InvalidTransaction();

        transaction.status = ValidationStatus.Confirmed;
        transaction.isConfirmed = true;

        _distributeTransactionFees(transaction);
        _updateValidatorMetrics(msg.sender, true);

        emit TransactionConfirmed(transactionId, msg.sender);
    }

    function registerValidator() external payable nonReentrant {
        if (msg.value < minimumStake) revert InsufficientStake();
        if (validators[msg.sender].isActive) revert AlreadyRegistered();

        validators[msg.sender] = Validator({
            stake: msg.value,
            successRate: 100,
            totalValidated: 0,
            reputationScore: 100,
            isActive: true,
            lastValidationTime: block.timestamp
        });

        validatorList.push(msg.sender);
        _grantRole(VALIDATOR_ROLE, msg.sender);

        emit ValidatorRegistered(msg.sender, msg.value);
    }

    function calculateFees(uint256 amount) public view returns (FeeStructure memory) {
        unchecked {
            return FeeStructure({
                baseFee: baseTransactionFee,
                validatorFee: (amount * validatorFeePercentage) / BASIS_POINTS,
                networkFee: (amount * networkFeePercentage) / BASIS_POINTS,
                aiProcessingFee: (amount * aiProcessingFeePercentage) / BASIS_POINTS
            });
        }
    }

    function _distributeTransactionFees(Transaction storage transaction) private {
        FeeStructure memory fees = transaction.fees;
        
        (bool success,) = transaction.receiver.call{value: transaction.amount}("");
        if (!success) revert TransferFailed();

        (success,) = msg.sender.call{value: fees.validatorFee}("");
        if (!success) revert TransferFailed();
    }

    function _updateValidatorMetrics(address validator, bool successful) private {
        Validator storage v = validators[validator];
        unchecked {
            v.totalValidated++;
            
            if (successful) {
                v.successRate = ((v.successRate * (v.totalValidated - 1)) + 100) / v.totalValidated;
                v.reputationScore = Math.min(v.reputationScore + 1, MAX_REPUTATION);
            } else {
                v.successRate = (v.successRate * (v.totalValidated - 1)) / v.totalValidated;
                v.reputationScore = v.reputationScore > 0 ? v.reputationScore - 1 : 0;
            }
            
            v.lastValidationTime = block.timestamp;
        }
    }

    function getActiveValidators() external view returns (address[] memory) {
        uint256 activeCount;
        uint256 length = validatorList.length;
        
        for (uint256 i; i < length;) {
            if (validators[validatorList[i]].isActive) {
                unchecked { ++activeCount; }
            }
            unchecked { ++i; }
        }

        address[] memory activeValidators = new address[](activeCount);
        uint256 currentIndex;
        
        for (uint256 i; i < length;) {
            if (validators[validatorList[i]].isActive) {
                activeValidators[currentIndex] = validatorList[i];
                unchecked { ++currentIndex; }
            }
            unchecked { ++i; }
        }

        return activeValidators;
    }

    function updateFeePercentage(string calldata feeType, uint256 newPercentage) external onlyRole(FEE_MANAGER_ROLE) {
        if (newPercentage > MAX_FEE_PERCENTAGE) revert FeeTooHigh();
        
        bytes32 feeTypeHash = keccak256(abi.encodePacked(feeType));
        if (feeTypeHash == keccak256("validator")) {
            validatorFeePercentage = newPercentage;
        } else if (feeTypeHash == keccak256("network")) {
            networkFeePercentage = newPercentage;
        } else if (feeTypeHash == keccak256("ai")) {
            aiProcessingFeePercentage = newPercentage;
        } else {
            revert InvalidFeeType();
        }

        emit FeeUpdated(feeType, newPercentage);
    }

    function updateBalance(address _validator, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        if (_validator == address(0)) revert InvalidAddress();
        if (_amount == 0) revert InsufficientAmount();

        unchecked {
            balances[_validator] += _amount;
        }

        emit BalanceUpdated(_validator, balances[_validator]);
    }

    receive() external payable {}
}