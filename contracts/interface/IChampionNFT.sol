// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IChampionNFT is IERC721Enumerable{

    
    function setDelivered(uint tokenId, bool pickup) external;
    function isDelivered(uint tokenId) external returns (bool);
}