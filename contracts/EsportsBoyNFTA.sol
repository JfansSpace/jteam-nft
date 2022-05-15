// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";
import "./interface/IERC20_USDT.sol";

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
  bytes32 public                        earlybirdRoot;          // the earlybird's MerkleRoot #1
  bytes32 public                        presaleRoot;              
  uint256 public                        publicPrice;              // usdt price
  uint256 public constant               ANGEL_SUPPLY = 300;       // 
  uint256 public constant               EARLYBIRD_SUPPLY = 300;   //
  uint256 public constant               PRE_SUPPLY = 300;         //
  uint256 public constant               PUBLI_SUPPLY = 100;       //
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
  mapping(address => uint256) public    earlyBirdMintLimit;             //address => the upper limit of the mint quantity of eraly birds period
  mapping(address => uint256) public    earlyBirdMintCount;             //address => the number of minted during the eraly birds period
  mapping(address => uint256) public    preSaleMintLimit;               //address => the upper limit of the mint quantity of preSale period
  mapping(address => uint256) public    preSaleMintCount;               //address => the number of minted during the preSale period

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
    require(amount == publicPrice * quantity, "amount is wrong");
    require(IERC20_USDT(usdt).balanceOf(_msgSender()) >=  amount, "balanceOf usdt is not enough");


    IERC20_USDT(usdt).transferFrom(_msgSender(), address(this), amount);

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
    require(preSaleMintCount[_msgSender()] + quantity <= preSaleMintLimit[_msgSender()], "the number of caller mint exceeds the upper limit");
    require(amount == publicPrice * quantity, "amount is wrong");
    require(IERC20_USDT(usdt).balanceOf(_msgSender()) >=  amount, "balanceOf usdt is not enough");


    IERC20_USDT(usdt).transferFrom(_msgSender(), address(this), amount);

    preSaleMintCount[_msgSender()] += quantity;
    preSaleCount += quantity;
    _safeMint(_msgSender(), quantity);
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
    require(EARLYBIRD_SUPPLY > 0, "EARLYBIRD_SUPPLY has not been set");
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

  function setEarlyBirdRoot(bytes32 _earlybirdRoot) external onlyOwner {
    earlybirdRoot = _earlybirdRoot;
  }

  function setPublicPrice(uint256 amount) external onlyOwner {
    require(amount > 0, "price must be greater than 0");
    publicPrice = amount;
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

  function setPreSaleMintLimit(address account, uint limit) external onlyOwner {
    preSaleMintLimit[account] = limit;
  }

  function setPreSaleMintLimitBatch(address[] memory accounts, uint[] memory limits) external onlyOwner {
    require(limits.length == accounts.length, "The two arrays are not equal in length");
    for (uint i = 0; i < accounts.length; i++) {
      preSaleMintLimit[accounts[i]] = limits[i];
    }
  }

  function setBridge(address _bridge) external onlyOwner {
    bridgeContractAddress = _bridge;
  }

  function withdrawUSDT() external onlyOwner {
    uint balance = IERC20_USDT(usdt).balanceOf(address(this));
    require(balance > 0, "no usdt balance");
    IERC20_USDT(usdt).transfer(_msgSender(), balance);
  }
}