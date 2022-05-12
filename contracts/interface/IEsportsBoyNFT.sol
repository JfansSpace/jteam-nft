// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;
import "erc721a/contracts/extensions/IERC721AQueryable.sol";

interface IEsportsBoyNFT is IERC721AQueryable{

    
    function setDelivered(uint tokenId, bool pickup) external;
    function isDelivered(uint tokenId) external returns (bool);
}