// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./AIIntegration.sol";

contract ViNixSyncToken is ERC20, Ownable, Pausable {
    AIIntegration public immutable aiIntegration;
    uint256 private immutable _maxSupply;
    uint8 private _status;
    
    // Metadata yang disimpan off-chain
    string public constant METADATA_URI = "ipfs://QmYourIPFSHash/metadata.json";
    
    event ValidationFailed(address indexed user);
    
    constructor(address _aiIntegration) 
        ERC20("ViNixSyncToken", "VINIX")
        Ownable(msg.sender) 
    {
        aiIntegration = AIIntegration(_aiIntegration);
        _maxSupply = 1_000_000_000 * 10 ** 18;
        _mint(msg.sender, _maxSupply);
    }
    
    modifier validateAI(address from, uint256 amount) {
        if(!aiIntegration.validateWithAI(from, amount)) {
            emit ValidationFailed(from);
            revert("AI:fail");
        }
        _;
    }
    
    function transfer(address to, uint256 amount) 
        public 
        override 
        validateAI(msg.sender, amount) 
        returns (bool) 
    {
        if(_status == 1) revert("P");
        return super.transfer(to, amount);
    }
    
    function transferFrom(address from, address to, uint256 amount)
        public
        override
        validateAI(from, amount)
        returns (bool)
    {
        if(_status == 1) revert("P");
        return super.transferFrom(from, to, amount);
    }
    
    function mint(address to, uint256 amount) 
        external 
        onlyOwner 
        validateAI(to, amount) 
    {
        if(_status == 1) revert("P");
        if(totalSupply() + amount > _maxSupply) revert("Max");
        _mint(to, amount);
    }
    
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
    
    function pause() external onlyOwner {
        _status = 1;
    }
    
    function unpause() external onlyOwner {
        _status = 0;
    }
}