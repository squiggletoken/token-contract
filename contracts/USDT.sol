// SPDX-License-Identifier: MIT
// Web-Address: https://squiggle.monster/
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20 {
  constructor() ERC20("Test USDT", "tUSDT") {
  }

  function decimals() public pure override returns (uint8) {
		return 18;
	}

  function mint(uint256 amount) external {
    _mint(msg.sender, amount);
  }

  function burn(uint256 amount) external {
    _burn(msg.sender, amount);
  }
}