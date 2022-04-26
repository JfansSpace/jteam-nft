// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./interface/IChampionNFTBridge.sol";

/*

Esports Boy NFT Contract: have 4 types of Wl, including prepaid angles, 
prepaid eraly birds, non-prepaid presale, and public sale.

1. angles and eraly birds do not need to pay on the mint day
2. reserve some special numbers.
3. allow one address mint more than one NFTs
4. reveal image urls


Core Methods：
publicMint 
presaleMint 
earlyBridMint 
angleMint 
*/
contract EsportsBoyNFT is ERC721Enumerable, Ownable, Pausable {
  using Strings for uint256;
  using Counters for Counters.Counter;

  address private                       bridgeContractAddress;  // contract used to set the NFT delivery status
  string private                        baseURI;
  string private                        notRevealedURI;           
  string private                        deliveredURI;             
  bytes32 private                       angleRoot;                // the angle's MerkleRoot
  bytes32 private                       earlybirdRoot;            
  bytes32 private                       presaleRoot;              
  mapping(uint256 => address) private   reserveMap;               // for tokenid reservation
  uint256 public                        publicPrice;              //
  uint256 public                        ANGEL_SUPPLY;             //
  uint256 public                        EARLYBIRD_SUPPLY;         //
  uint256 public                        PRE_SUPPLY;               //
  uint256 public                        PUBLI_SUPPLY;             //
  uint256 public                        angleSaleCount;           // keep track of angle mint number
  uint256 public                        earlyBridSaleCount;       
  uint256 public                        preSaleCount;             
  uint256 public                        publicSaleCount;
  uint256 public                        angleBeginId;                 //Angel period tokenId begin
  //uint256 public                        earlyBridBeginId;             //earlyBrid period tokenId begin
  Counters.Counter public               tokenIdTracker_angle;         //angle tokenId increment
  //Counters.Counter public               tokenIdTracker_earlyBrid;     //earlyBrid tokenId increment
  Counters.Counter public               tokenIdTracker;               //tokenId increment
  bool public                           isPublicSaleActive = false;     
  bool public                           isPreSaleActive = false;        
  bool public                           isEarlyBirdSaleActive = false;  
  bool public                           isAngelSaleActive = false;      //?angle already finished
  bool public                           isRevealed = false;             
  mapping(uint256 => bool) public       deliveryMap;                    //tokenId => whether or not deliered
  mapping(address => uint256) public    angleMintLimit;         //address => the upper limit of the mint quantity of Angel period
  mapping(address => uint256) public    angleMintCount;         //address => the number of minted during the Angel period

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
    tokenIdTracker._value = 0;
  }

  
  /* ----------- view function ------------ */
  function isDelivered(uint tokenId) external view returns (bool) {
    return deliveryMap[tokenId];
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  function currentTokenId() external view returns (uint256) {
    return tokenIdTracker.current();
  }

  // function currentEarlyBridTokenId() external view returns (uint256) {
  //   return tokenIdTracker_earlyBrid.current();
  // }

  function currentAngleTokenId() external view returns (uint256) {
    return tokenIdTracker_angle.current();
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
      if (reserveMap[tokenIdTracker.current()] == address(0) && !_exists(tokenIdTracker.current())) {
        return tokenIdTracker.current();
      }
      else
        tokenIdTracker.increment();
    }
    return 0;
  }


  /* ----------- external function ------------ */

  function publicMint(uint256 quantity) external payable 
    whenNotPaused
    publicSaleActive {
    require(_msgSender() == tx.origin, "No contracts allowed");
    require(quantity > 0, "quantity must be greater than 0");
    require(quantity + publicSaleCount <= PUBLI_SUPPLY,"Not enough PUBLI_SUPPLY");
    require(msg.value >= publicPrice * quantity, "Not enough ETH");

    publicSaleCount += quantity;
    for (uint i = 0; i < quantity; i++ ) {
        _safeMint(_msgSender(), getValidTokenId());
        IChampionNFTBridge(bridgeContractAddress).setFirstBuy(tokenIdTracker.current(), _msgSender());
        tokenIdTracker.increment();
    }
  }

  function presaleMint(uint256 quantity, bytes32[] calldata proof) external payable 
    whenNotPaused 
    preSaleActive {
    require(_msgSender() == tx.origin, "No contracts allowed");
    require(quantity > 0, "quantity must be greater than 0");
    require(quantity + preSaleCount <= PRE_SUPPLY,"Not enough PRE_SUPPLY");
    require(msg.value >= publicPrice * quantity, "Not enough ETH");
    require(MerkleProof.verify(proof, presaleRoot, keccak256(abi.encodePacked(_msgSender()))),"Address is not in presale list");

    preSaleCount += quantity;
    for (uint i = 0; i < quantity; i++ ) {
        _safeMint(_msgSender(), getValidTokenId());
        IChampionNFTBridge(bridgeContractAddress).setFirstBuy(tokenIdTracker.current(), _msgSender());
        tokenIdTracker.increment();
    }
  }

  function earlyBridMint(uint256 quantity, bytes32[] calldata proof) external payable
    whenNotPaused
    earlyBirdSaleActive {
    require(_msgSender() == tx.origin, "No contracts allowed");
    require(quantity > 0, "quantity must be greater than 0");
    require(quantity + earlyBridSaleCount <= EARLYBIRD_SUPPLY,"Not enough EARLYBIRD_SUPPLY");
    require(msg.value >= publicPrice * quantity, "Not enough ETH");
    require(MerkleProof.verify(proof, earlybirdRoot, keccak256(abi.encodePacked(_msgSender()))),"Address is not in earlybird list");

    earlyBridSaleCount += quantity;

    // for (uint i = 0; i < quantity; i++ ) {
    //     _safeMint(_msgSender(), tokenIdTracker_earlyBrid.current());
    //     IChampionNFTBridge(bridgeContractAddress).setFirstBuy(tokenIdTracker_earlyBrid.current(), _msgSender());
    //     tokenIdTracker_earlyBrid.increment();
    // }

    for (uint i = 0; i < quantity; i++ ) {
        _safeMint(_msgSender(), getValidTokenId());
        IChampionNFTBridge(bridgeContractAddress).setFirstBuy(tokenIdTracker.current(), _msgSender());
        tokenIdTracker.increment();
    }
  }

  function angleMint(uint256 quantity, bytes32[] calldata proof) external
    whenNotPaused
    angleSaleActive {
    require(_msgSender() == tx.origin, "No contracts allowed");
    require(quantity > 0, "quantity must be greater than 0");
    require(quantity + angleSaleCount <= ANGEL_SUPPLY, "Not enough ANGEL_SUPPLY");
    require(MerkleProof.verify(proof, angleRoot, keccak256(abi.encodePacked(_msgSender()))),"Address is not in angle list");
    require(angleMintCount[_msgSender()] + quantity <= angleMintLimit[_msgSender()], "the number of caller mint exceeds the upper limit");
    
    angleMintCount[_msgSender()] += quantity;
    angleSaleCount += quantity;

    for (uint i = 0; i < quantity; i++ ) {
      _safeMint(_msgSender(), tokenIdTracker_angle.current());
      IChampionNFTBridge(bridgeContractAddress).setFirstBuy(tokenIdTracker_angle.current(), _msgSender());
      tokenIdTracker_angle.increment();
    }
  }

  function mintReserve(uint tokenId) external whenNotPaused {
    require(reserveMap[tokenId] == _msgSender(), "the tokenId does not belong to you");
    _safeMint(_msgSender(), tokenId);
    IChampionNFTBridge(bridgeContractAddress).setFirstBuy(tokenId, _msgSender());
  }



  /* ----------- owner function ------------ */

  // only bridge owner can set delivery status 
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
    require(PUBLI_SUPPLY > 0, "PUBLI_SUPPLY has not been set");
    require(tokenIdTracker._value > 0, "the start tokenId has not been set");
    require(publicPrice > 0, "public price has not been set");
    isPublicSaleActive = active;
  }

  function setPreSale(bool active) external onlyOwner {
    require(PRE_SUPPLY > 0, "PRE_SUPPLY has not been set");
    require(tokenIdTracker._value > 0, "the start tokenId has not been set");
    require(publicPrice > 0, "public price has not been set");
    isPreSaleActive = active;
  }

  function setEarlyBirdSale(bool active) external onlyOwner {
    //require(EARLYBIRD_SUPPLY > 0, "EARLYBIRD_SUPPLY has not been set");
    //require(earlyBridBeginId > 0, "earlyBridBeginId has not been set");
    require(EARLYBIRD_SUPPLY > 0, "EARLYBIRD_SUPPLY has not been set");
    require(tokenIdTracker._value > 0, "the start tokenId has not been set");
    require(publicPrice > 0, "public price has not been set");
    isEarlyBirdSaleActive = active;
  }

  function setAngleSale(bool active) external onlyOwner {
    require(ANGEL_SUPPLY > 0, "ANGEL_SUPPLY has not been set");
    require(angleBeginId > 0, "angleBeginId has not been set");
    isAngelSaleActive = active;
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
  
  function setAngelSupply(uint256 amount) external onlyOwner {
    ANGEL_SUPPLY = amount;
  }

  function setEarlyBirdSupply(uint256 amount) external onlyOwner {
    EARLYBIRD_SUPPLY = amount;
  }

  function setPreSupply(uint256 amount) external onlyOwner {
    PRE_SUPPLY = amount;
  }

  function setPublicSupply(uint256 amount) external onlyOwner {
    PUBLI_SUPPLY = amount;
  }

  function setAngleBeginId(uint beginId) external onlyOwner {
    require(beginId > 0, "tokenId must be greater than 0");
    require(ANGEL_SUPPLY > 0, "ANGEL_SUPPLY has not been set");
    angleBeginId = beginId;
    tokenIdTracker_angle._value = angleBeginId;
  }

  // function setEarlyBridBeginId(uint beginId) external onlyOwner {
  //   require(beginId > 0, "tokenId must be greater than 0");
  //   require(EARLYBIRD_SUPPLY > 0, "EARLYBIRD_SUPPLY has not been set");
  //   require(angleBeginId > 0, "angleBeginId has not been set");
  //   require(beginId > angleBeginId + ANGEL_SUPPLY - 1, "earlyBridBeginId must be greater than the last angle period tokenId");
  //   earlyBridBeginId = beginId;
  //   tokenIdTracker_earlyBrid._value = earlyBridBeginId;
  // }

  function setBeginId(uint beginId) external onlyOwner {
    require(beginId > 0, "tokenId must be greater than 0");
    require(angleBeginId > 0, "angleBeginId has not been set");
    require(beginId > angleBeginId + ANGEL_SUPPLY - 1, "beginId must be greater than the last angle period tokenId");
    tokenIdTracker._value = beginId;
  }

  function setAngleMintLimit(address account, uint limit) external onlyOwner {
    angleMintLimit[account] = limit;
  }

  function setAngleMintLimitBatch(address[] memory accounts, uint[] memory limits) external onlyOwner {
    require(limits.length == accounts.length, "The two arrays are not equal in length");
    for (uint i = 0; i < accounts.length; i++) {
      angleMintLimit[accounts[i]] = limits[i];
    }
  }
  //ser reserve tokenid
  function setReserve(uint256 tokenId, address account) external onlyOwner {
    require(angleBeginId > 0, "angleBeginId has not been set");
    //require(earlyBridBeginId > 0, "earlyBridBeginId has not been set");
    require(!_exists(tokenId),"tokenId already exists");
    require(tokenId < angleBeginId || tokenId > (angleBeginId + ANGEL_SUPPLY - 1), "tokenId must be outside the range of angel period IDs");
    //require(tokenId < earlyBridBeginId || tokenId > (earlyBridBeginId + EARLYBIRD_SUPPLY - 1), "tokenId must be outside the range of earlyBrid period IDs");
    reserveMap[tokenId] = account;
  }

  //batch set reserve tokenid
  function setReserveBatch(uint256[] memory tokenIds, address[] memory accounts) external onlyOwner {
    require(angleBeginId > 0, "angleBeginId has not been set");
    //require(earlyBridBeginId > 0, "earlyBridBeginId has not been set");
    require(tokenIds.length == accounts.length, "The two arrays are not equal in length");
    for (uint i = 0; i < accounts.length; i++) {
      require(!_exists(tokenIds[i]),"tokenId already exists");
      require(tokenIds[i] < angleBeginId || tokenIds[i] > (angleBeginId + ANGEL_SUPPLY - 1), "tokenId must be outside the range of angel period IDs");
      //require(tokenIds[i] < earlyBridBeginId || tokenIds[i] > (earlyBridBeginId + EARLYBIRD_SUPPLY - 1), "tokenId must be outside the range of earlyBrid period IDs");
      reserveMap[tokenIds[i]] = accounts[i];
    }
  }

  function setBridge(address _bridge) external onlyOwner {
    bridgeContractAddress = _bridge;
  }

  function mintAdmin(uint256 tokenId, address to) external onlyOwner{
    require(angleBeginId > 0, "angleBeginId has not been set");
    //require(earlyBridBeginId > 0, "earlyBridBeginId has not been set");
    require(tokenId < angleBeginId || tokenId > (angleBeginId + ANGEL_SUPPLY - 1), "tokenId must be outside the range of angel period IDs");
    //require(tokenId < earlyBridBeginId || tokenId > (earlyBridBeginId + EARLYBIRD_SUPPLY - 1), "tokenId must be outside the range of earlyBrid period IDs");
    require(reserveMap[tokenId] == address(0), "the tokenId has been reserved");
    _safeMint(to, tokenId);
    IChampionNFTBridge(bridgeContractAddress).setFirstBuy(tokenId, to);
  }

  function withdraw() external onlyOwner {
    require(address(this).balance > 0, "no eth balance");
    //bool success = payable(msg.sender).send(address(this).balance);
    (bool sent, bytes memory data) = payable(msg.sender).call{value: address(this).balance}("");
    require(sent, "Payment did not go through!");
  }
}