// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./HybridChain.sol";

contract ValidatorReward {
    address public owner;
    mapping(address => uint256) public rewards;
    HybridChain public hybridChain;

    event RewardDistributed(address validator, uint256 amount);

    constructor(address _hybridChain) {
        owner = msg.sender;
        hybridChain = HybridChain(_hybridChain);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    function distributeRewards() public onlyOwner {
        address[] memory validators = hybridChain.getValidators();
        for (uint256 i = 0; i < validators.length; i++) {
            (,,,uint256 totalValidated) = hybridChain.validators(validators[i]);
            uint256 reward = totalValidated * 1 ether;
            rewards[validators[i]] += reward;
            emit RewardDistributed(validators[i], reward);
        }
    }
}