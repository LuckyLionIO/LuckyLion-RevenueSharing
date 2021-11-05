pragma solidity >= 0.6.0 <= 0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Example class - a mock class using delivering from ERC20
contract ERC20Token is ERC20 {
  constructor(uint256 initialBalance) ERC20("Test Token", "TOKEN"){
      _mint(msg.sender, initialBalance);
  }
}