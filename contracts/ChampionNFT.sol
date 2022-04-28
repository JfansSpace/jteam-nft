// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./interface/IChampionNFTBridge.sol";

/*

Esports Boy NFT Contract: have 4 types of Wl, including prepaid angels, 
prepaid eraly birds, non-prepaid presale, and public sale.

1. angels and eraly birds do not need to pay on the mint day
2. reserve some special numbers.
3. allow one address mint more than one NFTs
4. reveal image urls


Core Methods：
publicMint 
presaleMint 
earlyBirdMint 
angelMint 
*/
contract EsportsBoyNFT is ERC721Enumerable, Ownable, Pausable {
  using Strings for uint256;
  using Counters for Counters.Counter;

  address private                       bridgeContractAddress;  // contract used to set the NFT delivery status
  string private                        baseURI;
  string private                        notRevealedURI;           
  string private                        deliveredURI;             
  bytes32 private                       angelRoot;                // the angel's MerkleRoot
  bytes32 private                       earlybirdRoot;            
  bytes32 private                       presaleRoot;              
  mapping(uint256 => address) private   reserveMap;               // for tokenid reservation
  uint256 public                        publicPrice;              //
  uint256 public                        ANGEL_SUPPLY;             //
  uint256 public                        EARLYBIRD_SUPPLY;         //
  uint256 public                        PRE_SUPPLY;               //
  uint256 public                        PUBLI_SUPPLY;             //
  uint256 public                        angelSaleCount;           // keep track of angel mint number
  uint256 public                        earlyBirdSaleCount;       
  uint256 public                        preSaleCount;             
  uint256 public                        publicSaleCount;
  uint256 public                        angelBeginId;                 //Angel period tokenId begin
  //uint256 public                        earlyBirdBeginId;             //earlyBird period tokenId begin
  Counters.Counter public               tokenIdTracker_angel;         //angel tokenId increment
  //Counters.Counter public               tokenIdTracker_earlyBird;     //earlyBird tokenId increment
  Counters.Counter public               tokenIdTracker;               //tokenId increment
  bool public                           isPublicSaleActive = false;     
  bool public                           isPreSaleActive = false;        
  bool public                           isEarlyBirdSaleActive = false;  
  bool public                           isAngelSaleActive = false;      //?angel already finished
  bool public                           isRevealed = false;             
  mapping(uint256 => bool) public       deliveryMap;                    //tokenId => whether or not deliered
  mapping(address => uint256) public    angelMintLimit;                 //address => the upper limit of the mint quantity of Angel period
  mapping(address => uint256) public    angelMintCount;                 //address => the number of minted during the Angel period
  mapping(address => uint256) public    earlyBirdMintLimit;             //address => the upper limit of the mint quantity of eraly birds period
  mapping(address => uint256) public    earlyBirdMintCount;             //address => the number of minted during the eraly birds period

  /* ----------- modifier ------------ */

  //
  modifier angelSaleActive() {
    require(isAngelSaleActive, "AngelSale not active");
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
  //   return tokenIdTracker_earlyBird.current();
  // }

  function currentAngelTokenId() external view returns (uint256) {
    return tokenIdTracker_angel.current();
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

    //return back
    uint exceed_fee = msg.value - (publicPrice * quantity);
    if (exceed_fee > 0) {
      (bool sent, bytes memory data) = payable(msg.sender).call{value: exceed_fee}("");
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

    //return back
    uint exceed_fee = msg.value - (publicPrice * quantity);
    if (exceed_fee > 0) {
      (bool sent, bytes memory data) = payable(msg.sender).call{value: exceed_fee}("");
    }
  }

  function earlyBirdMint(uint256 quantity, bytes32[] calldata proof) external
    whenNotPaused
    earlyBirdSaleActive {
    require(_msgSender() == tx.origin, "No contracts allowed");
    require(quantity > 0, "quantity must be greater than 0");
    require(quantity + earlyBirdSaleCount <= EARLYBIRD_SUPPLY,"Not enough EARLYBIRD_SUPPLY");
    require(MerkleProof.verify(proof, earlybirdRoot, keccak256(abi.encodePacked(_msgSender()))),"Address is not in earlybird list");
    require(earlyBirdMintCount[_msgSender()] + quantity <= earlyBirdMintLimit[_msgSender()], "the number of caller mint exceeds the upper limit");

    earlyBirdMintCount[_msgSender()] += quantity;
    earlyBirdSaleCount += quantity;

    // for (uint i = 0; i < quantity; i++ ) {
    //     _safeMint(_msgSender(), tokenIdTracker_earlyBird.current());
    //     IChampionNFTBridge(bridgeContractAddress).setFirstBuy(tokenIdTracker_earlyBird.current(), _msgSender());
    //     tokenIdTracker_earlyBird.increment();
    // }

    for (uint i = 0; i < quantity; i++ ) {
        _safeMint(_msgSender(), getValidTokenId());
        IChampionNFTBridge(bridgeContractAddress).setFirstBuy(tokenIdTracker.current(), _msgSender());
        tokenIdTracker.increment();
    }
  }

  function angelMint(uint256 quantity, bytes32[] calldata proof) external
    whenNotPaused
    angelSaleActive {
    require(_msgSender() == tx.origin, "No contracts allowed");
    require(quantity > 0, "quantity must be greater than 0");
    require(quantity + angelSaleCount <= ANGEL_SUPPLY, "Not enough ANGEL_SUPPLY");
    require(MerkleProof.verify(proof, angelRoot, keccak256(abi.encodePacked(_msgSender()))),"Address is not in angel list");
    require(angelMintCount[_msgSender()] + quantity <= angelMintLimit[_msgSender()], "the number of caller mint exceeds the upper limit");
    
    angelMintCount[_msgSender()] += quantity;
    angelSaleCount += quantity;

    for (uint i = 0; i < quantity; i++ ) {
      _safeMint(_msgSender(), tokenIdTracker_angel.current());
      IChampionNFTBridge(bridgeContractAddress).setFirstBuy(tokenIdTracker_angel.current(), _msgSender());
      tokenIdTracker_angel.increment();
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
    //require(earlyBirdBeginId > 0, "earlyBirdBeginId has not been set");
    require(EARLYBIRD_SUPPLY > 0, "EARLYBIRD_SUPPLY has not been set");
    require(tokenIdTracker._value > 0, "the start tokenId has not been set");
    require(publicPrice > 0, "public price has not been set");
    isEarlyBirdSaleActive = active;
  }

  function setAngelSale(bool active) external onlyOwner {
    require(ANGEL_SUPPLY > 0, "ANGEL_SUPPLY has not been set");
    require(angelBeginId > 0, "angelBeginId has not been set");
    isAngelSaleActive = active;
  }

  function setRevealed(bool _revealed) external onlyOwner {
    isRevealed = _revealed;
  }

  function setAngelRoot(bytes32 _angelRoot) external onlyOwner {
    angelRoot = _angelRoot;
  }

  function setPresaleRoot(bytes32 _presaleRoot) external onlyOwner {
    presaleRoot = _presaleRoot;
  }

  function setEarlyBirdRoot(bytes32 _earlybirdRoot) external onlyOwner {
    earlybirdRoot = _earlybirdRoot;
  }

  function setPublicPrice(uint256 amount) external onlyOwner {
    require(amount > 0, "price must be greater than 0");
    publicPrice = amount;
  }
  
  function setAngelSupply(uint256 amount) external onlyOwner {
    require(amount > 0, "supply must be greater than 0");
    ANGEL_SUPPLY = amount;
  }

  function setEarlyBirdSupply(uint256 amount) external onlyOwner {
    require(amount > 0, "supply must be greater than 0");
    EARLYBIRD_SUPPLY = amount;
  }

  function setPreSupply(uint256 amount) external onlyOwner {
    require(amount > 0, "supply must be greater than 0");
    PRE_SUPPLY = amount;
  }

  function setPublicSupply(uint256 amount) external onlyOwner {
    require(amount > 0, "supply must be greater than 0");
    PUBLI_SUPPLY = amount;
  }

  function setAngelBeginId(uint beginId) external onlyOwner {
    require(beginId > 0, "tokenId must be greater than 0");
    require(ANGEL_SUPPLY > 0, "ANGEL_SUPPLY has not been set");
    angelBeginId = beginId;
    tokenIdTracker_angel._value = angelBeginId;
  }

  // function setEarlyBridBeginId(uint beginId) external onlyOwner {
  //   require(beginId > 0, "tokenId must be greater than 0");
  //   require(EARLYBIRD_SUPPLY > 0, "EARLYBIRD_SUPPLY has not been set");
  //   require(angelBeginId > 0, "angelBeginId has not been set");
  //   require(beginId > angelBeginId + ANGEL_SUPPLY - 1, "earlyBirdBeginId must be greater than the last angel period tokenId");
  //   earlyBirdBeginId = beginId;
  //   tokenIdTracker_earlyBird._value = earlyBirdBeginId;
  // }

  function setBeginId(uint beginId) external onlyOwner {
    require(beginId > 0, "tokenId must be greater than 0");
    require(angelBeginId > 0, "angelBeginId has not been set");
    require(beginId > angelBeginId + ANGEL_SUPPLY - 1, "beginId must be greater than the last angel period tokenId");
    tokenIdTracker._value = beginId;
  }

  function setAngelMintLimit(address account, uint limit) external onlyOwner {
    angelMintLimit[account] = limit;
  }

  function setAngelMintLimitBatch(address[] memory accounts, uint[] memory limits) external onlyOwner {
    require(limits.length == accounts.length, "The two arrays are not equal in length");
    for (uint i = 0; i < accounts.length; i++) {
      angelMintLimit[accounts[i]] = limits[i];
    }
  }

  function setEarlyBirdMintLimit(address account, uint limit) external onlyOwner {
    earlyBirdMintLimit[account] = limit;
  }

  function setEarlyBirdMintLimitBatch(address[] memory accounts, uint[] memory limits) external onlyOwner {
    require(limits.length == accounts.length, "The two arrays are not equal in length");
    for (uint i = 0; i < accounts.length; i++) {
      earlyBirdMintLimit[accounts[i]] = limits[i];
    }
  }

  //ser reserve tokenid
  function setReserve(uint256 tokenId, address account) external onlyOwner {
    require(angelBeginId > 0, "angelBeginId has not been set");
    //require(earlyBirdBeginId > 0, "earlyBirdBeginId has not been set");
    require(!_exists(tokenId),"tokenId already exists");
    require(tokenId < angelBeginId || tokenId > (angelBeginId + ANGEL_SUPPLY - 1), "tokenId must be outside the range of angel period IDs");
    //require(tokenId < earlyBirdBeginId || tokenId > (earlyBirdBeginId + EARLYBIRD_SUPPLY - 1), "tokenId must be outside the range of earlyBird period IDs");
    reserveMap[tokenId] = account;
  }

  //batch set reserve tokenid
  function setReserveBatch(uint256[] memory tokenIds, address[] memory accounts) external onlyOwner {
    require(angelBeginId > 0, "angelBeginId has not been set");
    //require(earlyBirdBeginId > 0, "earlyBirdBeginId has not been set");
    require(tokenIds.length == accounts.length, "The two arrays are not equal in length");
    for (uint i = 0; i < accounts.length; i++) {
      require(!_exists(tokenIds[i]),"tokenId already exists");
      require(tokenIds[i] < angelBeginId || tokenIds[i] > (angelBeginId + ANGEL_SUPPLY - 1), "tokenId must be outside the range of angel period IDs");
      //require(tokenIds[i] < earlyBirdBeginId || tokenIds[i] > (earlyBirdBeginId + EARLYBIRD_SUPPLY - 1), "tokenId must be outside the range of earlyBird period IDs");
      reserveMap[tokenIds[i]] = accounts[i];
    }
  }

  function setBridge(address _bridge) external onlyOwner {
    bridgeContractAddress = _bridge;
  }

  function mintAdmin(uint256 tokenId, address to) external onlyOwner{
    require(angelBeginId > 0, "angelBeginId has not been set");
    //require(earlyBirdBeginId > 0, "earlyBirdBeginId has not been set");
    require(tokenId < angelBeginId || tokenId > (angelBeginId + ANGEL_SUPPLY - 1), "tokenId must be outside the range of angel period IDs");
    //require(tokenId < earlyBirdBeginId || tokenId > (earlyBirdBeginId + EARLYBIRD_SUPPLY - 1), "tokenId must be outside the range of earlyBird period IDs");
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