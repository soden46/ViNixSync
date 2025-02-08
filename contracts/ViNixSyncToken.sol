// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./AIIntegration.sol";

contract ViNixSyncToken is ERC20, Ownable, Pausable {
    AIIntegration public aiIntegration;

    constructor(address _aiIntegration) ERC20("ViNixSyncToken", "VINIX") Ownable(msg.sender) {
        aiIntegration = AIIntegration(_aiIntegration);
        _mint(msg.sender, 1_000_000_000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner whenNotPaused {
        require(aiIntegration.validateWithAI(to, amount), "AI validation failed");
        _mint(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function transfer(address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        require(aiIntegration.validateWithAI(msg.sender, amount), "AI validation failed");
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override whenNotPaused returns (bool) {
        require(aiIntegration.validateWithAI(sender, amount), "AI validation failed");
        return super.transferFrom(sender, recipient, amount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}