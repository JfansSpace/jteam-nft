// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ChampionCollaborator is OwnableUpgradeable {


    struct Collaborator {
        uint percentage;
        bool active;
    }
    

    address[] private                               allCollaborators;
    mapping(address => Collaborator) private        CollaboratorMap;


    receive() external payable {}
    fallback() external payable {}


    function __initialize() external initializer {
        __Ownable_init();
    }

    function getCollaborator() public view returns(Collaborator memory) {
        return CollaboratorMap[_msgSender()];
    }

    function getCollaborator(address account) public view onlyOwner returns(Collaborator memory) {
        return CollaboratorMap[account];
    }

    function getAllCollaborator() public view onlyOwner returns(address[] memory) {
        return allCollaborators;
    }

    function totalPercentage() public view returns(uint) {
        uint sum = 0;
        for (uint i = 0; i < allCollaborators.length; i++) {
            Collaborator memory collaborator = CollaboratorMap[allCollaborators[i]];
            if (collaborator.active) {
                sum += collaborator.percentage;
            }
        }
        return sum;
    }

    function addCollaborator(address account, uint percentage) public onlyOwner {
        require(account != address(0), "Collaborator cannot be an empty address");
        require(!CollaboratorMap[account].active, "Collaborator already exists");
        require((totalPercentage() + percentage) <= 10000, "totalPercentage will be greater than 10000");

        CollaboratorMap[account] = Collaborator(percentage, true);
        allCollaborators.push(account);
    }

    function setCollaborator(address account, uint percentage) public onlyOwner {
        require(account != address(0), "Collaborator cannot be an empty address");
        require(CollaboratorMap[account].active, "Collaborator is not exists");
        require((totalPercentage() - CollaboratorMap[account].percentage + percentage) <= 10000, "totalPercentage will be greater than 10000");
        CollaboratorMap[account].percentage = percentage;
    }

    function delCollaborator(address account) public onlyOwner {
        require(account != address(0), "Collaborator cannot be an empty address");
        require(CollaboratorMap[account].active, "Collaborator is not exists");
        delete CollaboratorMap[account];
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "no balance to withdraw");
        for (uint i = 0; i < allCollaborators.length; i++) {
            Collaborator memory collaborator = CollaboratorMap[allCollaborators[i]];
            if (collaborator.active) {
                (bool sent, bytes memory data) = payable(allCollaborators[i]).call{value: (balance * collaborator.percentage) / 10000}("");
                require(sent, "Failed to send Ether");
            }
        }
    }
}