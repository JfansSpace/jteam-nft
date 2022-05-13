// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
contract EsportsBoyNFTA is ERC721AQueryable, Ownable, Pausable {
  using Strings for uint256;

  address private                       bridgeContractAddress;  // contract used to set the NFT delivery status
  string private                        baseURI;
  string private                        notRevealedURI;           
  string private                        deliveredURI;             
  bytes32 public                        angelRoot;                // the angel's MerkleRoot
  bytes32 public                        earlybirdRoot_1;          // the earlybird's MerkleRoot #1
  bytes32 public                        earlybirdRoot_2;          // the earlybird's MerkleRoot #2
  bytes32 public                        earlybirdRoot_3;          // the earlybird's MerkleRoot #3
  bytes32 public                        presaleRoot;              
  uint256 public                        publicPrice;              // usdt price
  uint256 public                        ANGEL_SUPPLY;             //
  uint256 public                        EARLYBIRD_SUPPLY_1;        //
  uint256 public                        EARLYBIRD_SUPPLY_2;        //
  uint256 public                        EARLYBIRD_SUPPLY_3;        //
  uint256 public                        PRE_SUPPLY;               //
  uint256 public                        PUBLI_SUPPLY;             //
  uint256 public                        angelSaleCount;           // keep track of angel mint number
  uint256 public                        earlyBirdSaleCount;       
  uint256 public                        preSaleCount;
  uint256 public                        publicSaleCount;
  bool public                           isPublicSaleActive = false;     
  bool public                           isPreSaleActive = false;        
  bool public                           isEarlyBirdSaleActive = false;  
  bool public                           isAngelSaleActive = false;      //?angel already finished
  bool public                           isRevealed = false;
  address public                        usdt;
  mapping(uint256 => bool) public       deliveryMap;                    //tokenId => whether or not deliered
  mapping(address => uint256) public    angelMintLimit;                 //address => the upper limit of the mint quantity of Angel period
  mapping(address => uint256) public    angelMintCount;                 //address => the number of minted during the Angel period
  mapping(address => uint256) public    earlyBirdMintLimit_1;           //address => the upper limit of the mint quantity of eraly birds period #1
  mapping(address => uint256) public    earlyBirdMintCount_1;           //address => the number of minted during the eraly birds period #1
  mapping(address => uint256) public    earlyBirdMintLimit_2;           //address => the upper limit of the mint quantity of eraly birds period #2
  mapping(address => uint256) public    earlyBirdMintCount_2;           //address => the number of minted during the eraly birds period #2
  mapping(address => uint256) public    earlyBirdMintLimit_3;           //address => the upper limit of the mint quantity of eraly birds period #3
  mapping(address => uint256) public    earlyBirdMintCount_3;           //address => the number of minted during the eraly birds period #3

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
  ) ERC721A(_name, _symbol) {
    baseURI = _initBaseURI;
    notRevealedURI = _initNotRevealedURI;
    deliveredURI = _initDeliveredURI;
    _currentIndex = 1;
  }

  
  /* ----------- view function ------------ */
  function isDelivered(uint tokenId) external view returns (bool) {
    return deliveryMap[tokenId];
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  function currentTokenId() external view returns (uint256) {
    return _currentIndex;
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



  /* ----------- external function ------------ */

  function publicMint(uint256 quantity, uint256 amount) external 
    whenNotPaused
    publicSaleActive {
    require(_msgSender() == tx.origin, "No contracts allowed");
    require(quantity > 0, "quantity must be greater than 0");
    require(quantity + publicSaleCount <= PUBLI_SUPPLY,"Not enough PUBLI_SUPPLY");
    require(amount >= publicPrice * quantity, "Not enough USDT");
    require(IERC20(usdt).balanceOf(_msgSender()) >=  amount, "balanceOf usdt is not enough");


    IERC20(usdt).transferFrom(_msgSender(), address(this), amount);

    publicSaleCount += quantity;
    _safeMint(_msgSender(), quantity);
  }

  function presaleMint(uint256 quantity, bytes32[] calldata proof, uint256 amount) external 
    whenNotPaused 
    preSaleActive {
    require(_msgSender() == tx.origin, "No contracts allowed");
    require(quantity > 0, "quantity must be greater than 0");
    require(quantity + preSaleCount <= PRE_SUPPLY,"Not enough PRE_SUPPLY");
    require(MerkleProof.verify(proof, presaleRoot, keccak256(abi.encodePacked(_msgSender()))),"Address is not in presale list");
    require(amount >= publicPrice * quantity, "Not enough USDT");
    require(IERC20(usdt).balanceOf(_msgSender()) >=  amount, "balanceOf usdt is not enough");


    IERC20(usdt).transferFrom(_msgSender(), address(this), amount);

    preSaleCount += quantity;
    _safeMint(_msgSender(), quantity);
  }

  function earlyBirdMint_1(uint256 quantity, bytes32[] calldata proof) external
    whenNotPaused
    earlyBirdSaleActive {
    require(_msgSender() == tx.origin, "No contracts allowed");
    require(quantity > 0, "quantity must be greater than 0");
    require(quantity + earlyBirdSaleCount <= EARLYBIRD_SUPPLY_1 + EARLYBIRD_SUPPLY_2 + EARLYBIRD_SUPPLY_3,"Not enough EARLYBIRD_SUPPLY");
    require(MerkleProof.verify(proof, earlybirdRoot_1, keccak256(abi.encodePacked(_msgSender()))),"Address is not in earlybird list");
    require(earlyBirdMintCount_1[_msgSender()] + quantity <= earlyBirdMintLimit_1[_msgSender()], "the number of caller mint exceeds the upper limit");

    earlyBirdMintCount_1[_msgSender()] += quantity;
    earlyBirdSaleCount += quantity;

    _safeMint(_msgSender(), quantity);
  }

  function earlyBirdMint_2(uint256 quantity, bytes32[] calldata proof) external
    whenNotPaused
    earlyBirdSaleActive {
    require(_msgSender() == tx.origin, "No contracts allowed");
    require(quantity > 0, "quantity must be greater than 0");
    require(quantity + earlyBirdSaleCount <= EARLYBIRD_SUPPLY_1 + EARLYBIRD_SUPPLY_2 + EARLYBIRD_SUPPLY_3,"Not enough EARLYBIRD_SUPPLY");
    require(MerkleProof.verify(proof, earlybirdRoot_2, keccak256(abi.encodePacked(_msgSender()))),"Address is not in earlybird list");
    require(earlyBirdMintCount_2[_msgSender()] + quantity <= earlyBirdMintLimit_2[_msgSender()], "the number of caller mint exceeds the upper limit");

    earlyBirdMintCount_2[_msgSender()] += quantity;
    earlyBirdSaleCount += quantity;

    _safeMint(_msgSender(), quantity);
  }

  function earlyBirdMint_3(uint256 quantity, bytes32[] calldata proof) external
    whenNotPaused
    earlyBirdSaleActive {
    require(_msgSender() == tx.origin, "No contracts allowed");
    require(quantity > 0, "quantity must be greater than 0");
    require(quantity + earlyBirdSaleCount <= EARLYBIRD_SUPPLY_1 + EARLYBIRD_SUPPLY_2 + EARLYBIRD_SUPPLY_3,"Not enough EARLYBIRD_SUPPLY");
    require(MerkleProof.verify(proof, earlybirdRoot_3, keccak256(abi.encodePacked(_msgSender()))),"Address is not in earlybird list");
    require(earlyBirdMintCount_3[_msgSender()] + quantity <= earlyBirdMintLimit_3[_msgSender()], "the number of caller mint exceeds the upper limit");

    earlyBirdMintCount_3[_msgSender()] += quantity;
    earlyBirdSaleCount += quantity;

    _safeMint(_msgSender(), quantity);
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

    _safeMint(_msgSender(), quantity);
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

  function setUSDT(address _usdt) public onlyOwner {
    usdt = _usdt;
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
    require(publicPrice > 0, "public price has not been set");
    isPublicSaleActive = active;
  }

  function setPreSale(bool active) external onlyOwner {
    require(PRE_SUPPLY > 0, "PRE_SUPPLY has not been set");
    require(publicPrice > 0, "public price has not been set");
    isPreSaleActive = active;
  }

  function setEarlyBirdSale(bool active) external onlyOwner {
    require(EARLYBIRD_SUPPLY_1 > 0, "EARLYBIRD_SUPPLY_1 has not been set");
    require(EARLYBIRD_SUPPLY_2 > 0, "EARLYBIRD_SUPPLY_2 has not been set");
    require(EARLYBIRD_SUPPLY_3 > 0, "EARLYBIRD_SUPPLY_3 has not been set");
    isEarlyBirdSaleActive = active;
  }

  function setAngelSale(bool active) external onlyOwner {
    require(ANGEL_SUPPLY > 0, "ANGEL_SUPPLY has not been set");
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

  function setEarlyBirdRoot_1(bytes32 _earlybirdRoot) external onlyOwner {
    earlybirdRoot_1 = _earlybirdRoot;
  }

  function setEarlyBirdRoot_2(bytes32 _earlybirdRoot) external onlyOwner {
    earlybirdRoot_2 = _earlybirdRoot;
  }

  function setEarlyBirdRoot_3(bytes32 _earlybirdRoot) external onlyOwner {
    earlybirdRoot_3 = _earlybirdRoot;
  }

  function setPublicPrice(uint256 amount) external onlyOwner {
    require(amount > 0, "price must be greater than 0");
    publicPrice = amount;
  }
  
  function setAngelSupply(uint256 amount) external onlyOwner {
    require(amount > 0, "supply must be greater than 0");
    ANGEL_SUPPLY = amount;
  }

  function setEarlyBirdSupply_1(uint256 amount) external onlyOwner {
    require(amount > 0, "supply must be greater than 0");
    EARLYBIRD_SUPPLY_1 = amount;
  }

  function setEarlyBirdSupply_2(uint256 amount) external onlyOwner {
    require(amount > 0, "supply must be greater than 0");
    EARLYBIRD_SUPPLY_2 = amount;
  }

  function setEarlyBirdSupply_3(uint256 amount) external onlyOwner {
    require(amount > 0, "supply must be greater than 0");
    EARLYBIRD_SUPPLY_3 = amount;
  }

  function setPreSupply(uint256 amount) external onlyOwner {
    require(amount > 0, "supply must be greater than 0");
    PRE_SUPPLY = amount;
  }

  function setPublicSupply(uint256 amount) external onlyOwner {
    require(amount > 0, "supply must be greater than 0");
    PUBLI_SUPPLY = amount;
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

  function setEarlyBirdMintLimit_1(address account, uint limit) external onlyOwner {
    earlyBirdMintLimit_1[account] = limit;
  }

  function setEarlyBirdMintLimit_2(address account, uint limit) external onlyOwner {
    earlyBirdMintLimit_2[account] = limit;
  }

  function setEarlyBirdMintLimit_3(address account, uint limit) external onlyOwner {
    earlyBirdMintLimit_3[account] = limit;
  }

  function setEarlyBirdMintLimitBatch_1(address[] memory accounts, uint[] memory limits) external onlyOwner {
    require(limits.length == accounts.length, "The two arrays are not equal in length");
    for (uint i = 0; i < accounts.length; i++) {
      earlyBirdMintLimit_1[accounts[i]] = limits[i];
    }
  }

  function setEarlyBirdMintLimitBatch_2(address[] memory accounts, uint[] memory limits) external onlyOwner {
    require(limits.length == accounts.length, "The two arrays are not equal in length");
    for (uint i = 0; i < accounts.length; i++) {
      earlyBirdMintLimit_2[accounts[i]] = limits[i];
    }
  }

  function setEarlyBirdMintLimitBatch_3(address[] memory accounts, uint[] memory limits) external onlyOwner {
    require(limits.length == accounts.length, "The two arrays are not equal in length");
    for (uint i = 0; i < accounts.length; i++) {
      earlyBirdMintLimit_3[accounts[i]] = limits[i];
    }
  }

  function setBridge(address _bridge) external onlyOwner {
    bridgeContractAddress = _bridge;
  }

  function mintAdmin(address to, uint256 quantity) external onlyOwner{
    _safeMint(to, quantity);
  }

  // function withdraw() external onlyOwner {
  //   require(address(this).balance > 0, "no eth balance");
  //   (bool sent, bytes memory data) = payable(msg.sender).call{value: address(this).balance}("");
  //   require(sent, "Payment did not go through!");
  // }

  function withdrawUSDT() external onlyOwner {
    uint balance = IERC20(usdt).balanceOf(address(this));
    require(balance > 0, "no usdt balance");
    IERC20(usdt).transferFrom(address(this), _msgSender(), balance);
  }
}