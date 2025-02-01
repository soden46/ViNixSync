const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("HybridChain Contract", function () {
    let HybridChain;
    let hybridChain;
    let AIOracle;
    let aiOracle;
    let owner;
    let validator1;
    let user1;
    let user2;

    beforeEach(async function () {
        // Deploy AIOracle mock
        const AIOracle = await ethers.getContractFactory("AIOracle");
        const aiOracle = await AIOracle.deploy();
        console.log("AIOracle deployed at:", aiOracle.address);
        
        // Deploy HybridChain contract
        const HybridChain = await ethers.getContractFactory("HybridChain");
        const hybridChain = await HybridChain.deploy(aiOracle.address, ethers.parseUnits("0.1", 18), ethers.parseUnits("1", 18));
        await hybridChain.deployed();
        console.log("Haybrid Chain deployed at:", hybridChain.address);

        // Get signers
        [owner, validator1, user1, user2] = await ethers.getSigners();
    });

    describe("Transaction Creation", function () {
        it("should create a transaction successfully", async function () {
            const receiver = user2.address;
            const amount = ethers.utils.parseEther("1"); // Correct usage of parseEther

            // Create transaction
            await expect(hybridChain.connect(user1).createTransaction(receiver, { value: amount }))
                .to.emit(hybridChain, "TransactionCreated")
                .withArgs(0, user1.address, receiver, amount);

            // Check transaction details
            const transaction = await hybridChain.getTransaction(0);
            expect(transaction.sender).to.equal(user1.address);
            expect(transaction.receiver).to.equal(receiver);
            expect(transaction.amount).to.equal(amount);
            expect(transaction.status).to.equal(0); // Pending
        });

        it("should fail if amount is less than fees", async function () {
            const receiver = user2.address;
            const amount = ethers.utils.parseEther("0.05"); // Insufficient amount for fees

            await expect(
                hybridChain.connect(user1).createTransaction(receiver, { value: amount })
            ).to.be.revertedWith("Amount must be greater than fees");
        });
    });

    describe("Validator Registration", function () {
        it("should allow a validator to register with sufficient stake", async function () {
            const stakeAmount = ethers.utils.parseEther("1");

            // Register validator
            await expect(hybridChain.connect(validator1).registerValidator({ value: stakeAmount }))
                .to.emit(hybridChain, "ValidatorRegistered")
                .withArgs(validator1.address, stakeAmount);

            // Check validator status
            const validatorData = await hybridChain.getValidatorData(validator1.address);
            expect(validatorData.isActive).to.be.true;
        });

        it("should fail if stake is insufficient", async function () {
            const stakeAmount = ethers.utils.parseEther("0.05");

            await expect(
                hybridChain.connect(validator1).registerValidator({ value: stakeAmount })
            ).to.be.revertedWith("Insufficient stake");
        });
    });

    describe("Transaction Confirmation", function () {
        it("should allow a validator to confirm a transaction", async function () {
            const receiver = user2.address;
            const amount = ethers.utils.parseEther("1");

            // User1 creates a transaction
            await hybridChain.connect(user1).createTransaction(receiver, { value: amount });

            // Register a validator and confirm transaction
            await hybridChain.connect(validator1).registerValidator({ value: ethers.utils.parseEther("1") });

            // Simulate AI Oracle approval (mock the validation)
            await aiOracle.setApproval(true);

            // Confirm transaction
            await expect(hybridChain.connect(validator1).confirmTransaction(0))
                .to.emit(hybridChain, "TransactionConfirmed")
                .withArgs(0, validator1.address);

            const transaction = await hybridChain.getTransaction(0);
            expect(transaction.status).to.equal(1); // Confirmed
            expect(transaction.isConfirmed).to.be.true;
        });

        it("should fail if AI Oracle rejects the transaction", async function () {
            const receiver = user2.address;
            const amount = ethers.utils.parseEther("1");

            // User1 creates a transaction
            await hybridChain.connect(user1).createTransaction(receiver, { value: amount });

            // Register a validator and confirm transaction
            await hybridChain.connect(validator1).registerValidator({ value: ethers.utils.parseEther("1") });

            // Simulate AI Oracle rejection (mock the validation)
            await aiOracle.setApproval(false);

            await expect(hybridChain.connect(validator1).confirmTransaction(0))
                .to.be.revertedWith("AI Oracle rejected transaction");
        });
    });
});
