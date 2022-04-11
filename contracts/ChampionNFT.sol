// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./interface/IChampionNFTBridge.sol";

/*

冠軍俱樂部NFT合約， 負責發行冠軍俱樂部NFT， 發行分 4個階段：
天使期：300套，20%off，鎖定三個月
早鳥期：300套，不打折，不鎖定
預售期：300套，無折扣，無鎖倉
公開發售期：100套 ，無折扣，無鎖倉
核心方程：
publicMint 公開發售铸币方法
presaleMint 預售期铸币方法
earlyBridMint 早鳥期铸币方法
angleMint 天使期铸币方法
*/
contract ChampionNFT is ERC721Enumerable, Ownable, Pausable {
  using Strings for uint256;
  using Counters for Counters.Counter;

  address private                       bridgeContractAddress;  // 负责设置 冠軍俱樂部NFT 提货状态的合约
  string private                        baseURI;
  string private                        notRevealedURI;           //未公开 URI
  string private                        deliveredURI;             //已提货 URI
  bytes32 private                       angleRoot;                //天使期 MerkleRoot
  bytes32 private                       earlybirdRoot;            //早鸟期 MerkleRoot
  bytes32 private                       presaleRoot;              //预售期 MerkleRoot
  mapping(uint256 => address) private   reserveMap;               //预定Mapping  预定的tokenId => 预定地址
  uint256 public                        publicPrice = 0.1 ether;  //公开销售的价格
  uint256 public constant               ANGEL_SUPPLY = 300;       //天使期 铸币总数
  uint256 public constant               EARLYBIRD_SUPPLY = 300;   //早鸟期 铸币总数
  uint256 public constant               PRE_SUPPLY = 300;         //预售期 铸币总数
  uint256 public constant               PUBLI_SUPPLY = 100;       //公开销售期 铸币总数
  uint256 public                        angleSaleCount;           //天使期 铸币计数
  uint256 public                        earlyBridSaleCount;       //天使期 铸币计数
  uint256 public                        preSaleCount;             //天使期 铸币计数
  uint256 public                        publicSaleCount;                //天使期 铸币计数
  Counters.Counter public               tokenIdTracker;                 //tokenId 自增计数器
  bool public                           isPublicSaleActive = false;     //是否激活公开销售
  bool public                           isPreSaleActive = false;        //是否激活预售期
  bool public                           isEarlyBirdSaleActive = false;  //是否激活早鸟期
  bool public                           isAngelSaleActive = false;      //是否激活天使期
  bool public                           isRevealed = false;             //nft 公开状态
  mapping(uint256 => bool) public       deliveryMap;                    //提货Mapping  tokenId => 是否已提货
  mapping(address => bool) public       angleSaleMints;                 //天使期 地址 => 是否已经铸币

  /* ----------- modifier ------------ */

  //
  modifier angleSaleActive() {
    require(isAngelSaleActive, "AngleSale not active");
    _;
  }

  modifier earlyBirdSaleActive() {
    require(isEarlyBirdSaleActive, "EarlyBirdSale not active");
    _;
  }

  modifier preSaleActive() {
    require(isPreSaleActive, "PreSale not active");
    _;
  }

  modifier publicSaleActive() {
    require(isPublicSaleActive, "PublicSale not active");
    _;
  }

  modifier onlyBridge_Owner() {
    require(bridgeContractAddress == _msgSender() || owner() == _msgSender(), "caller neither owner nor bridge");
    _;
  }

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initBaseURI,
    string memory _initNotRevealedURI,
    string memory _initDeliveredURI
  ) ERC721(_name, _symbol) {
    baseURI = _initBaseURI;
    notRevealedURI = _initNotRevealedURI;
    deliveredURI = _initDeliveredURI;
    tokenIdTracker._value = 1;
  }

  
  /* ----------- view function ------------ */
  function isDelivered(uint tokenId) external view returns (bool) {
    return deliveryMap[tokenId];
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  function walletOfOwner(address _owner) public view returns (uint256[] memory) {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    for (uint256 i; i < ownerTokenCount; i++) {
      tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokenIds;
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );
    
    if(isRevealed == false) {
        return notRevealedURI;
    }

    if (deliveryMap[tokenId]) {
      return bytes(deliveredURI).length > 0
        ? string(abi.encodePacked(deliveredURI, tokenId.toString()))
        : "";
    }

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString()))
        : "";
  }

  /* ----------- internal function ------------ */
  function getValidTokenId() internal returns(uint) {
    while (true) {
      if (reserveMap[tokenIdTracker.current()] == address(0)) {
        return tokenIdTracker.current();
      }
      else
        tokenIdTracker.increment();
    }
    return 0;
  }


  /* ----------- external function ------------ */

  /**
    * public mint  公開銷售 鑄幣方法
    */
  function publicMint(uint256 quantity) external payable 
    whenNotPaused
    publicSaleActive {
    require(_msgSender() == tx.origin, "No contracts allowed");
    require(quantity + publicSaleCount <= PUBLI_SUPPLY,"Not enough PUBLI_SUPPLY");
    require(msg.value >= publicPrice * quantity, "Not enough ETH");

    publicSaleCount += quantity;
    for (uint i; i < quantity; i++ ) {
        _safeMint(_msgSender(), getValidTokenId());
        //調用 bridgeContractAddress 合約 設置記錄 首次購買人
        IChampionNFTBridge(bridgeContractAddress).setFristBuy(tokenIdTracker.current(), _msgSender());
        tokenIdTracker.increment();
    }
  }

  /**
    * presale mint 預售期 鑄幣方法
    */
  function presaleMint(uint256 quantity, bytes32[] calldata proof) external payable 
    whenNotPaused 
    preSaleActive {
    require(_msgSender() == tx.origin, "No contracts allowed");
    require(quantity + preSaleCount <= PRE_SUPPLY,"Not enough PRE_SUPPLY");
    require(msg.value >= publicPrice * quantity, "Not enough ETH");
    require(MerkleProof.verify(proof, presaleRoot, keccak256(abi.encodePacked(_msgSender()))),"Address is not in presale list");

    preSaleCount += quantity;
    for (uint i; i < quantity; i++ ) {
        _safeMint(_msgSender(), getValidTokenId());
        //調用 bridgeContractAddress 合約 設置記錄 首次購買人
        IChampionNFTBridge(bridgeContractAddress).setFristBuy(tokenIdTracker.current(), _msgSender());
        tokenIdTracker.increment();
    }
  }

  /**
    * earlybrid mint 早鳥期 鑄幣方法 
    */
  function earlyBridMint(uint256 quantity, bytes32[] calldata proof) external payable
    whenNotPaused
    earlyBirdSaleActive {
    require(_msgSender() == tx.origin, "No contracts allowed");
    require(quantity + earlyBridSaleCount <= EARLYBIRD_SUPPLY,"Not enough EARLYBIRD_SUPPLY");
    require(msg.value >= publicPrice * quantity, "Not enough ETH");
    require(MerkleProof.verify(proof, earlybirdRoot, keccak256(abi.encodePacked(_msgSender()))),"Address is not in earlybird list");

    earlyBridSaleCount += quantity;
    for (uint i; i < quantity; i++ ) {
        _safeMint(_msgSender(), getValidTokenId());
        //調用 bridgeContractAddress 合約 設置記錄 首次購買人
        IChampionNFTBridge(bridgeContractAddress).setFristBuy(tokenIdTracker.current(), _msgSender());
        tokenIdTracker.increment();
    }
  }

  /**
    * angle mint  天使期 鑄幣方法  天使期已經提前收過ETH，鑄造方法不收取ETH
    */
  function angleMint(bytes32[] calldata proof) external
    whenNotPaused
    angleSaleActive {
    require(_msgSender() == tx.origin, "No contracts allowed");
    require(1 + angleSaleCount <= ANGEL_SUPPLY,"Not enough ANGEL_SUPPLY");
    require(!angleSaleMints[_msgSender()], "Address already minted their angle mint");
    require(MerkleProof.verify(proof, angleRoot, keccak256(abi.encodePacked(_msgSender()))),"Address is not in angle list");

    //天使期 鑄幣 每個地址只能鑄造一個nft, 鑄造完成後記錄狀態，防止重複鑄造
    angleSaleMints[_msgSender()] = true;
    angleSaleCount += 1;

    _safeMint(_msgSender(), getValidTokenId());
    IChampionNFTBridge(bridgeContractAddress).setFristBuy(tokenIdTracker.current(), _msgSender());
    tokenIdTracker.increment();
  }

  /**
    * airdrop minting  预定鑄造方法 只允許鑄造 reserveMap 中 地址對應的 tokenID
    */
  function mintReserve(uint tokenId) external whenNotPaused {
    require(reserveMap[tokenId] == _msgSender(), "the tokenId does not belong to you");
    _safeMint(_msgSender(), tokenId);
    IChampionNFTBridge(bridgeContractAddress).setFristBuy(tokenId, _msgSender());
  }



  /* ----------- owner function ------------ */

  //設置 nft 被提貨狀態, 允許 Bridge 合約或者 owner 調用
  function setDelivered(uint tokenId, bool delivery) public whenNotPaused onlyBridge_Owner {
    deliveryMap[tokenId] = delivery;
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  function setNotRevealedURI(string memory _notRevealedURI) external onlyOwner {
    notRevealedURI = _notRevealedURI;
  }

  function setDeliveredURI(string memory _deliveredURI) external onlyOwner {
    deliveredURI = _deliveredURI;
  }

  function setBaseURI(string memory _newBaseURI) external onlyOwner {
    baseURI = _newBaseURI;
  }

  function setPublicSale(bool active) external onlyOwner {
    isPublicSaleActive = active;
  }

  function setPreSale(bool active) external onlyOwner {
    isPreSaleActive = active;
  }

  function setAngleSale(bool active) external onlyOwner {
    isAngelSaleActive = active;
  }

  function setEarlyBirdSale(bool active) external onlyOwner {
    isEarlyBirdSaleActive = active;
  }

  function setRevealed(bool _revealed) external onlyOwner {
    isRevealed = _revealed;
  }

  function setAngleRoot(bytes32 _angleRoot) external onlyOwner {
    angleRoot = _angleRoot;
  }

  function setPresaleRoot(bytes32 _presaleRoot) external onlyOwner {
    presaleRoot = _presaleRoot;
  }

  function setEarlyBirdRoot(bytes32 _earlybirdRoot) external onlyOwner {
    earlybirdRoot = _earlybirdRoot;
  }

  function setPublicPrice(uint256 amount) external onlyOwner {
    publicPrice = amount;
  }

  //設置預定tokenId 信息
  function setReserve(uint256 tokenId, address account) external onlyOwner {
    reserveMap[tokenId] = account;
  }

  //批量設置預定tokenId 信息
  function setReserveBatch(uint256[] memory tokenIds, address[] memory accounts) external onlyOwner {
    require(tokenIds.length == accounts.length, "The two arrays are not equal in length");
    for (uint i = 0; i < accounts.length; i++) {
      reserveMap[tokenIds[i]] = accounts[i];
    }
  }

  function setBridge(address _bridge) external onlyOwner {
    bridgeContractAddress = _bridge;
  }

  function mintAdmin(address to) external onlyOwner{
    require(msg.sender == tx.origin, "No contracts allowed");
    _safeMint(to, getValidTokenId());
    IChampionNFTBridge(bridgeContractAddress).setFristBuy(tokenIdTracker.current(), to);
    tokenIdTracker.increment();
  }

  // 提款
  function withdraw() external onlyOwner {
    require(address(this).balance > 0, "no eth balance");
    bool success = payable(msg.sender).send(address(this).balance);
    require(success, "Payment did not go through!");
  }
}