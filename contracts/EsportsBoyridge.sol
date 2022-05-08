// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;
import "./interface/IEsportsBoyNFT.sol";
import "./BasicBridge.sol";
import "./lib/EsportsBoyEIP712Upgradeable.sol";


/*

冠軍俱樂部NFT Bridge 合约 部署在 以太坊， 负责接受验证者调用，设置冠軍俱樂部NFT 的提货状态
核心方法：
delivery： 由验证者调用，把冠軍俱樂部NFT申请提货并缴费勋章的数据签名打包，发送给Bridge 合约，验证通过之后，设置冠軍俱樂部NFT 的提货状态

*/

contract EsportsBoyBridge is BasicBridge, EsportsBoyEIP712Upgradeable {

    /* --- EVENTS --- */
    event Delivery(address indexed operator, address sender, uint256 tokenId, uint256 value, bytes32 transactionHash);
    event SignedForTransferFromForeign(address indexed signer, bytes32 transactionHash);


    /* --- FIELDS --- */
    mapping(bytes32 => bool) public     transfersSigned;
    mapping(bytes32 => uint256) public  numTransfersSigned;
    address public                      jt_nft;
    uint256 public                      medalamount; // number of medals required for have the right fo delivery
    uint256 public                      deployedAtBlock; // Used by bridge client to determine initial block number to start listening for transfers


    /* --- MODIFIERs --- */
    modifier onlyNFT_Owner() {
        require(owner() == _msgSender() || jt_nft == _msgSender(), "caller neither owner nor nft");
        _;
    }


    /* --- EXTERNAL / PUBLIC  METHODS --- */
    function __initialize(address _nft, uint amount) external initializer {
        __BasicBridge_init();
        __EsportsBoyEIP712_init();
        jt_nft = _nft;
        medalamount = amount;
        deployedAtBlock = block.number;
    }

    function setNft(address _nft) public onlyOwner{
        jt_nft = _nft;
    }

    function setMedalamount(uint amount) public onlyOwner{
        medalamount = amount;
    }

    function delivery(address sender, uint256 tokenId, uint256 value, bytes32 transactionHash, string memory signature) public whenNotPaused onlyValidator{
        require(IEsportsBoyNFT(jt_nft).ownerOf(tokenId) == sender, "the tokenId does not belong to sender");
        require(!IEsportsBoyNFT(jt_nft).isDelivered(tokenId), "the tokenId has been delivered");
        require(verify(_msgSender(), sender, tokenId, value, transactionHash, signature), "signature verify failed");
        require(value >= medalamount, "not enough medals to delivery");

        bytes32 hashMsg = keccak256(abi.encodePacked(sender, tokenId, value, transactionHash));
        bytes32 hashSender = keccak256(abi.encodePacked(_msgSender() , hashMsg));

        require(!transfersSigned[hashSender], "Transfer already signed by this validator");
        transfersSigned[hashSender] = true;

        uint256 signed = numTransfersSigned[hashMsg];
        require(!isAlreadyProcessed(signed), "Transfer already processed");
        // the check above assumes that the case when the value could be overflew will not happen in the addition operation below
        signed = signed + 1;

        numTransfersSigned[hashMsg] = signed;

        emit SignedForTransferFromForeign(_msgSender(), transactionHash);

        if (signed >= requiredSignatures) {
            // If the bridge contract does not own enough tokens to transfer
            // it will cause funds lock on the home side of the bridge
            numTransfersSigned[hashMsg] = markAsProcessed(signed);
            IEsportsBoyNFT(jt_nft).setDelivered(tokenId, true);
            emit Delivery(_msgSender(), sender, tokenId, value, transactionHash);
        }
    }

    function markAsProcessed(uint256 _v) internal pure returns(uint256) {
        return _v | 2 ** 255;
    }

    function isAlreadyProcessed(uint256 _number) public pure returns(bool) {
        return _number & 2**255 == 2**255;
    }
}