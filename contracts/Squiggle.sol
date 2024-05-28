// SPDX-License-Identifier: MIT
// Web-Address: https://squiggle.monster/
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Squiggle is ERC20 {
  constructor(address[] memory addresses, uint256[] memory amounts) ERC20("Squiggle Monster", "SQGL") {
    for (uint i = 0; i < addresses.length; i++) {
      _mint(addresses[i], amounts[i]);
    }
  }
}