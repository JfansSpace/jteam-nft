// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "./BasicBridge.sol";


/*

Esports Boys NFT Delivery Contract will be depolyed on the foreign chains, 
and will be used to redeem the products

Core Methods：
transferMedals： receive fan medals on the foreign chains, 
then the bridge client will listen to the events for redemption
*/

contract EsportsBoyDelivery is PausableUpgradeable, OwnableUpgradeable, ERC1155HolderUpgradeable {


    event TransferMedals(address indexed operator, uint tokenId, uint medalId, uint amount);


    address public                                  fans_medal ;
    uint public                                     fans_medal_Id;
    uint256 public                                  deployedAtBlock; // Used by bridge client to determine initial block number to start listening for transfers


    function __initialize(address _medal, uint _medal_Id) external initializer {
        __Ownable_init();
        __Pausable_init();
        fans_medal  = _medal;
        fans_medal_Id = _medal_Id;
        deployedAtBlock = block.number;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setMedal(address _medal, uint _medal_Id) public onlyOwner{
        fans_medal  = _medal;
        fans_medal_Id = _medal_Id;
    }
    
    function transferMedals(uint tokenId, uint amount) public whenNotPaused {
        IERC1155Upgradeable(fans_medal).safeTransferFrom(_msgSender(), address(this), fans_medal_Id, amount, "0x0");
        emit TransferMedals(_msgSender(), tokenId, fans_medal_Id, amount);
    }

    function withdrawMedal() public onlyOwner {
        uint balance = IERC1155Upgradeable(fans_medal).balanceOf(address(this), fans_medal_Id);
        require(balance > 0, "");
        IERC1155Upgradeable(fans_medal).safeTransferFrom(address(this), _msgSender(), fans_medal_Id, balance, "0x0");
    }
}