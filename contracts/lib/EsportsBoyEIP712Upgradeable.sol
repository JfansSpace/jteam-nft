// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";

contract EsportsBoyEIP712Upgradeable is EIP712Upgradeable {

    bytes public constant   MESSAGE = "TransferMedals(address signer,address sender,uint256 tokenId,uint256 value,bytes32 transactionHash)";
    string public constant  NAME = "ChampionNFT";
    string public constant  VERSION = "1.0";

    

    function __EsportsBoyEIP712_init() internal onlyInitializing {
        __EIP712_init(NAME, VERSION);
    }

    //recover（V4）
    function recoverV4(
        address signer,
        address sender,
        uint256 tokenId,
        uint256 value,
        bytes32 transactionHash,
        bytes memory signature
    ) internal view returns (address) {
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            keccak256(MESSAGE),
            signer,
            sender,
            tokenId,
            value,
            transactionHash
        )));
        return ECDSAUpgradeable.recover(digest, signature);
    }

    //verify
    function verify(
        address from,
        address sender,
        uint256 tokenId,
        uint256 value,
        bytes32 transactionHash,
        string memory signature
    ) public view returns (bool) {
        bytes memory _signature = hexToByte(signature);
        address signer = recoverV4(from, sender, tokenId, value, transactionHash, _signature);
        return signer == from;
    }

    function hexToByte(string memory s) internal pure returns (bytes memory) {
        bytes memory b = bytes(s);
        
        require(b.length%2 == 0, "Invalid length of key string");
        bytes memory ret = new bytes(b.length/2);
        
        for (uint i=0; i<b.length/2; ++i) {
            ret[i] = bytes1(hexCharToByte(uint8(b[2 * i])) * 16 + hexCharToByte(uint8(b[2 * i+1])));
        }
        return ret;
    }
        
    function hexCharToByte(uint8 c) internal pure returns (uint8) {
        if(bytes1(c) >= bytes1('0') && bytes1(c) <= bytes1('9'))
            return c - uint8(bytes1('0'));
        if(bytes1(c) >= bytes1('a') && bytes1(c) <= bytes1('f'))
            return 10 + c - uint8(bytes1('a'));
        if(bytes1(c) >= bytes1('A') && bytes1(c) <= bytes1('F'))
            return 10 + c - uint8(bytes1('A'));
        else
            revert("Invalid character in key string");
    }
}