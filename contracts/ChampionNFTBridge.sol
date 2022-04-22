// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;
import "./interface/IChampionNFT.sol";
import "./BasicBridge.sol";
import "./lib/ChampionEIP712Upgradeable.sol";


/*

冠軍俱樂部NFT Bridge 合约 部署在 以太坊， 负责接受验证者调用，设置冠軍俱樂部NFT 的提货状态
核心方法：
setFirstBuy： 由冠軍俱樂部NFT合约调用，在冠軍俱樂部NFT铸造之时，把首次购买人信息写入Bridge 合约
delivery： 由验证者调用，把冠軍俱樂部NFT申请提货并缴费勋章的数据签名打包，发送给Bridge 合约，验证通过之后，设置冠軍俱樂部NFT 的提货状态

*/

contract ChampionNFTBridge is BasicBridge, ChampionEIP712Upgradeable {

    /* --- EVENTS --- */
    event SetFirstBuy(address indexed operator, uint tokenId, address account);
    event SetFirstBuy_Validator(address indexed operator, uint tokenId, address account, bytes32 transactionHash);
    event Delivery(address indexed operator, address sender, uint256 tokenId, uint256 value, bytes32 transactionHash);
    event SignedForTransferFromForeign(address indexed signer, bytes32 transactionHash);


    /* --- FIELDS --- */
    mapping(uint => address) public     firstBuyMap;      //tokenID => account
    mapping(bytes32 => bool) public     transfersSigned;
    mapping(bytes32 => uint256) public  numTransfersSigned;
    address public                      jt_nft;
    uint256 public                      medalamount_lv1; // number of medals required for have the right fo delivery
    uint256 public                      medalamount_lv2; // number of medals required for no right of delivery
    uint256 public                      deployedAtBlock; // Used by bridge client to determine initial block number to start listening for transfers


    /* --- MODIFIERs --- */
    modifier onlyNFT_Owner() {
        require(owner() == _msgSender() || jt_nft == _msgSender(), "caller neither owner nor nft");
        _;
    }


    /* --- EXTERNAL / PUBLIC  METHODS --- */
    function __initialize(address _nft, uint amount_lv1, uint amount_lv2) external initializer {
        __BasicBridge_init();
        __ChampionEIP712_init();
        jt_nft = _nft;
        medalamount_lv1 = amount_lv1;
        medalamount_lv2 = amount_lv2;
        deployedAtBlock = block.number;
    }

    function setNft(address _nft) public onlyOwner{
        jt_nft = _nft;
    }

    function setMedalamount(uint amount_lv1, uint amount_lv2) public onlyOwner{
        medalamount_lv1 = amount_lv1;
        medalamount_lv2 = amount_lv2;
    }

    function setFirstBuy(uint tokenId, address account) public onlyNFT_Owner {
        require(IChampionNFT(jt_nft).ownerOf(tokenId) == account, "the tokenId does not belong to account");
        firstBuyMap[tokenId] = account;
        emit SetFirstBuy(_msgSender(), tokenId, account);
    }

    function delivery(address sender, uint256 tokenId, uint256 value, bytes32 transactionHash, string memory signature) public whenNotPaused onlyValidator{
        require(IChampionNFT(jt_nft).ownerOf(tokenId) == sender, "the tokenId does not belong to sender");
        require(!IChampionNFT(jt_nft).isDelivered(tokenId), "the tokenId has been delivered");
        require(verify(_msgSender(), sender, tokenId, value, transactionHash, signature), "signature verify failed");
        
        if (firstBuyMap[tokenId] == sender) {
            require(value >= medalamount_lv1, "not enough medals to delivery - lv1");
        }
        else {
            require(value >= medalamount_lv2, "not enough medals to delivery - lv2");
        }

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
            IChampionNFT(jt_nft).setDelivered(tokenId, true);
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