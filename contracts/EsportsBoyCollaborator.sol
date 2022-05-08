// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/*
Add, set, remove, get collaborators who are eliable to receive the royalties
*/
contract EsportsBoyCollaborator is OwnableUpgradeable {


    address[] private                               allCollaborators;
    mapping(address => uint) private                CollaboratorMap;  // Collaborator address => Collaborator percentage


    receive() external payable {}
    fallback() external payable {}


    function __initialize() external initializer {
        __Ownable_init();
    }

    function getCollaborator() public view returns(uint) {
        return CollaboratorMap[_msgSender()];
    }

    function getCollaborator(address account) public view onlyOwner returns(uint) {
        return CollaboratorMap[account];
    }

    function getAllCollaborator() public view onlyOwner returns(address[] memory) {
        return allCollaborators;
    }

    function totalPercentage() public view returns(uint) {
        uint sum = 0;
        for (uint i = 0; i < allCollaborators.length; i++) {
            if (allCollaborators[i] != address(0)) {
                sum += CollaboratorMap[allCollaborators[i]];
            }
        }
        return sum;
    }

    function addCollaborator(address account, uint percentage) public onlyOwner {
        require(account != address(0), "Collaborator cannot be an empty address");
        require(percentage > 0, "percentage must greater than 0");
        require(CollaboratorMap[account] == 0, "Collaborator already exists");
        require((totalPercentage() + percentage) <= 10000, "totalPercentage will be greater than 10000");

        CollaboratorMap[account] = percentage;
        allCollaborators.push(account);
    }

    function setCollaborator(address account, uint percentage) public onlyOwner {
        require(account != address(0), "Collaborator cannot be an empty address");
        require(percentage > 0, "percentage must greater than 0");
        require(CollaboratorMap[account] > 0, "Collaborator is not exists");
        require((totalPercentage() - CollaboratorMap[account] + percentage) <= 10000, "totalPercentage will be greater than 10000");
        CollaboratorMap[account] = percentage;
    }

    function delCollaborator(address account) public onlyOwner {
        require(account != address(0), "Collaborator cannot be an empty address");
        require(CollaboratorMap[account] > 0, "Collaborator is not exists");
        delete CollaboratorMap[account];

        for (uint i = 0; i < allCollaborators.length; i++) {
            if (allCollaborators[i] == account) {
                delete allCollaborators[i];
            }
        }
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "no balance to withdraw");
        for (uint i = 0; i < allCollaborators.length; i++) {
            if (allCollaborators[i] != address(0)) {
                uint percentage = CollaboratorMap[allCollaborators[i]];
                (bool sent, bytes memory data) = payable(allCollaborators[i]).call{value: (balance * percentage) / 10000}("");
                require(sent, "Failed to send Ether");
            }
        }
    }
}