// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";


contract FanMedal is ERC1155, Ownable{
    
    uint public                 fans_medal_Id;
    uint256 public constant     SUPPLY = 10000000;
    
    constructor(string memory uri, address to, uint id) ERC1155(uri) {
        fans_medal_Id = id;
        _mint(to, fans_medal_Id, SUPPLY, '0x0');
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }
}