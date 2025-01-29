// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HybridChain {
    struct Transaction {
        address sender;
        address receiver;
        uint256 amount;
        uint256 timestamp;
        bool isConfirmed;
    }

    struct Validator {
        address validatorAddress;
        uint256 stake;
        uint256 successRate;
        uint256 totalValidated;
    }

    address public owner;
    Transaction[] public transactions;
    mapping(address => uint256) public balances;
    mapping(address => Validator) public validators;
    address[] public validatorList;

    event TransactionCreated(address sender, address receiver, uint256 amount);
    event TransactionConfirmed(uint256 transactionId, address validator);
    event ValidatorRegistered(address validator);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function registerValidator(uint256 stake) public {
        require(stake > 0, "Stake must be greater than zero");
        require(validators[msg.sender].stake == 0, "Validator already registered");

        validators[msg.sender] = Validator(msg.sender, stake, 100, 0);
        validatorList.push(msg.sender);

        emit ValidatorRegistered(msg.sender);
    }

    function createTransaction(address receiver, uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        transactions.push(Transaction(msg.sender, receiver, amount, block.timestamp, false));
        emit TransactionCreated(msg.sender, receiver, amount);
    }

    function confirmTransaction(uint256 transactionId) public {
        require(validators[msg.sender].stake > 0, "Only validators can confirm transactions");
        require(transactionId < transactions.length, "Invalid transaction ID");
        require(!transactions[transactionId].isConfirmed, "Transaction already confirmed");

        transactions[transactionId].isConfirmed = true;
        validators[msg.sender].totalValidated += 1;

        emit TransactionConfirmed(transactionId, msg.sender);
    }

    function getValidators() public view returns (address[] memory) {
        return validatorList;
    }
}
