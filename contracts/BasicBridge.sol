// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract BasicBridge is OwnableUpgradeable, PausableUpgradeable{

    /* --- EVENTS --- */

    event ValidatorAdded (address validator);
    event ValidatorRemoved (address validator);
    event RequiredSignaturesChanged (uint256 requiredSignatures);

    /* --- FIELDS --- */
    mapping(address => bool) internal   validators;
    uint256 public validatorCount;
    uint256 public requiredSignatures;
    

    /* --- MODIFIERs --- */

    modifier onlyValidator() {
        require(isValidator(_msgSender()), "caller is not a validator");
        _;
    }

    function __BasicBridge_init() internal onlyInitializing {
        __Ownable_init();
        __Pausable_init();
    }

    /* --- EXTERNAL / PUBLIC  METHODS --- */

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function addValidator(address _validator) external onlyOwner {
        require(_validator != address(0), "Validator address should not be 0x0");
        require(_validator != owner(), "Validator address should not be owner");
        require(!isValidator(_validator), "New validator should be an existing validator");
        validatorCount = validatorCount + 1;
        validators[_validator] = true;
        emit ValidatorAdded(_validator);
    }

    function removeValidator(address _validator) external onlyOwner {
        require(validatorCount > requiredSignatures, "Removing validator should not make validator count be < requiredSignatures");
        require(isValidator(_validator), "Cannot remove address that is not a validator");
        validators[_validator] = false;
        validatorCount = validatorCount - 1;
        emit ValidatorRemoved(_validator);
    }

    function setRequiredSignatures(uint256 _requiredSignatures) external onlyOwner {
        require(validatorCount >= _requiredSignatures, "New requiredSignatures should be greater than num of validators");
        require(_requiredSignatures != 0, "New requiredSignatures should be > than 0");
        requiredSignatures = _requiredSignatures;
        emit RequiredSignaturesChanged(_requiredSignatures);
    }

    function isValidator(address _validator) public view returns(bool) {
        return validators[_validator] == true;
    }
}