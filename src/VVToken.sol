pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VVToken is ERC20, Ownable {
    
    constructor(address initialOwner) 
        ERC20("VegaVoting", "VV") 
        Ownable(initialOwner) 
    {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}