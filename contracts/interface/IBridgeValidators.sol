// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;

interface IBridgeValidators {
    function isValidator(address _validator) external view returns(bool);
    function requiredSignatures() external view returns(uint256);
    function owner() external view returns(address); 
}