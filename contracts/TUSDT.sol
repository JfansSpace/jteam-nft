// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract TUSDT is ERC20 {
    constructor(
    string memory _name,
    string memory _symbol
  ) ERC20(_name, _symbol) {
      _mint(msg.sender, 50000000000000);
  }

  function decimals() public view virtual override returns (uint8) {
      return 6;
  }
}