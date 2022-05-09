const { expect, assert } = require('chai');
const truffleAssert = require('truffle-assertions');
const { ethers } = require('ethers');
const { MerkleTree } = require('merkletreejs')
const keccak256 = require('keccak256')
// Load compiled artifacts
const EsportsBoyNFT = artifacts.require("EsportsBoyNFT");
const EsportsBoyBridge = artifacts.require("EsportsBoyBridge");
const { sign } = require("./utils/mint");

// Start test block
contract('EsportsBoyNFT Test', function (accounts) {
    
    describe('check for EsportsBoyNFT',() => {
        let nft = null;
        let bridge = null;
        let angelAddresses = [accounts[0],accounts[1],accounts[2]];
        let earlybirdAddresses = [accounts[3],accounts[4],accounts[5]];
        let presaleAddresses = [accounts[6],accounts[7],accounts[8]];
        let options = {
            hashLeaves: true,
            sort:true,
            duplicateOdd: false,
            isBitcoinTree: false
        }
        const angelRoot = new MerkleTree(angelAddresses, keccak256, options)
        const earlybirdRoot = new MerkleTree(earlybirdAddresses, keccak256, options)
        const presaleRoot = new MerkleTree(presaleAddresses, keccak256, options)
        const owner = accounts[0];
        const _initBaseURI = "http://base.uri/"
        const _initNotRevealedUri = "http://notrevealed.uri/"
        const _pickupUri = "http://pickup.uri/";

        const address_0 = "0x0000000000000000000000000000000000000000";
        
        beforeEach(async function () {
            nft = await EsportsBoyNFT.new("Champion-nft", "CNFT", _initBaseURI, _initNotRevealedUri, _pickupUri);
            bridge = await EsportsBoyBridge.new();
            await bridge.__initialize(nft.address, 1000);
            await nft.setBridge(bridge.address);
        });

        it("check for init", async () => {
            assert.equal(await nft.name(), "Champion-nft");
            assert.equal(await nft.symbol(), "CNFT");
        });

        it("check for set setAngelBeginId", async () => {
            await truffleAssert.reverts(nft.setAngelBeginId(0), "tokenId must be greater than 0");
            await truffleAssert.reverts(nft.setAngelBeginId(1000), "ANGEL_SUPPLY has not been set");
            await nft.setAngelSupply(300)
            await nft.setAngelBeginId(1000)

            assert.equal((await nft.angelBeginId()).toNumber(), 1000);
            assert.equal((await nft.currentAngelTokenId()).toNumber(), 1000);
        });

        it("check for set setEarlyBirdBeginId_2", async () => {
            await truffleAssert.reverts(nft.setEarlyBirdBeginId_2(0), "tokenId must be greater than 0");
            await truffleAssert.reverts(nft.setEarlyBirdBeginId_2(300), "EARLYBIRD_SUPPLY_2 has not been set");
            await nft.setEarlyBirdSupply_2(9)

            await truffleAssert.reverts(nft.setEarlyBirdBeginId_2(300), "angelBeginId has not been set");
            await nft.setAngelSupply(300)
            await nft.setAngelBeginId(1)
            await truffleAssert.reverts(nft.setEarlyBirdBeginId_2(300), "earlyBirdBeginId_2 must be greater than the last angel period tokenId");
            await nft.setEarlyBirdBeginId_2(301)

            assert.equal((await nft.earlyBirdBeginId_2()).toNumber(), 301);
            assert.equal((await nft.currentEarlyBirdTokenId_2()).toNumber(), 301);
        });

        it("check for set setEarlyBirdBeginId_3", async () => {
            await truffleAssert.reverts(nft.setEarlyBirdBeginId_3(0), "tokenId must be greater than 0");
            await truffleAssert.reverts(nft.setEarlyBirdBeginId_3(982), "EARLYBIRD_SUPPLY_3 has not been set");
            await nft.setEarlyBirdSupply_3(9)

            await truffleAssert.reverts(nft.setEarlyBirdBeginId_3(982), "earlyBirdBeginId_2 has not been set");
            await nft.setAngelSupply(300)
            await nft.setAngelBeginId(1)
            await nft.setEarlyBirdSupply_2(9)
            await nft.setEarlyBirdBeginId_2(982)

            await truffleAssert.reverts(nft.setEarlyBirdBeginId_3(990), "earlyBirdBeginId_3 must be greater than the last earlyBird period #2 tokenId");
            await nft.setEarlyBirdBeginId_3(991)

            assert.equal((await nft.earlyBirdBeginId_3()).toNumber(), 991);
            assert.equal((await nft.currentEarlyBirdTokenId_3()).toNumber(), 991);
        });

        it("check for set setBeginId", async () => {
            await truffleAssert.reverts(nft.setBeginId(0), "tokenId must be greater than 0");
            await truffleAssert.reverts(nft.setBeginId(1000), "angelBeginId has not been set");

            await nft.setAngelSupply(300)
            await nft.setAngelBeginId(1000) // 1000 ~ 1299

            await truffleAssert.reverts(nft.setBeginId(1299), "beginId must be greater than the last angel period tokenId");
            await nft.setBeginId(1300)

            assert.equal((await nft.currentTokenId()).toNumber(), 1300);
        });

        it("check for set setReserve", async () => {
            await truffleAssert.reverts(nft.setReserve(0, owner), "angelBeginId has not been set");

            await nft.setAngelSupply(300)
            await nft.setAngelBeginId(1) // 1 ~ 300
            await nft.setEarlyBirdSupply_2(9)
            await nft.setEarlyBirdBeginId_2(982) // 982 ~ 990
            await nft.setEarlyBirdSupply_3(9)
            await nft.setEarlyBirdBeginId_3(991) // 991 ~ 999
            await nft.mintAdmin(301, owner);

            await truffleAssert.reverts(nft.setReserve(301, owner), "tokenId already exists");

            await truffleAssert.reverts(nft.setReserve(1, owner), "tokenId must be outside the range of angel period IDs");
            await truffleAssert.reverts(nft.setReserve(136, owner), "tokenId must be outside the range of angel period IDs");
            await truffleAssert.reverts(nft.setReserve(300, owner), "tokenId must be outside the range of angel period IDs");
            await nft.setReserve(0, owner);
            await nft.setReserve(302, owner);
        });
 
        it("check for tokenURI", async () => {
            await nft.setAngelSupply(300)
            await nft.setAngelBeginId(1) // 1 ~ 300
            await nft.setEarlyBirdSupply_2(9)
            await nft.setEarlyBirdBeginId_2(982) // 982 ~ 990
            await nft.setEarlyBirdSupply_3(9)
            await nft.setEarlyBirdBeginId_3(991) // 991 ~ 999

            await truffleAssert.reverts(nft.tokenURI(1), "ERC721Metadata: URI query for nonexistent token");
            await nft.mintAdmin(301, owner)
            var url = await nft.tokenURI(301);
            assert.equal(url, _initNotRevealedUri);

            await nft.setRevealed(true);
            var url = await nft.tokenURI(301);
            assert.equal(url, _initBaseURI + "301");

            await truffleAssert.reverts(nft.setDelivered(301, true, {from:accounts[1]}), "caller neither owner nor bridge");
            await nft.setDelivered(301, true);
            var url = await nft.tokenURI(301);
            assert.equal(url, _pickupUri + "301"); 
        });

        it("check for set mintAdmin ", async () => {
            await truffleAssert.reverts(nft.mintAdmin(0, owner), "angelBeginId has not been set");
            await nft.setAngelSupply(300)
            await nft.setAngelBeginId(1) // 1 ~ 300
            await truffleAssert.reverts(nft.mintAdmin(0, owner), "earlyBirdBeginId_2 has not been set");
            await nft.setEarlyBirdSupply_2(9)
            await nft.setEarlyBirdBeginId_2(982) // 982 ~ 990
            await truffleAssert.reverts(nft.mintAdmin(0, owner), "earlyBirdBeginId_3 has not been set");
            await nft.setEarlyBirdSupply_3(9)
            await nft.setEarlyBirdBeginId_3(991) // 991 ~ 999

            await truffleAssert.reverts(nft.mintAdmin(1, owner), "tokenId must be outside the range of angel period IDs");
            await truffleAssert.reverts(nft.mintAdmin(123, owner), "tokenId must be outside the range of angel period IDs");
            await truffleAssert.reverts(nft.mintAdmin(300, owner), "tokenId must be outside the range of angel period IDs");

            await truffleAssert.reverts(nft.mintAdmin(982, owner), "tokenId must be outside the range of earlyBird period #2 IDs");
            await truffleAssert.reverts(nft.mintAdmin(988, owner), "tokenId must be outside the range of earlyBird period #2 IDs");
            await truffleAssert.reverts(nft.mintAdmin(990, owner), "tokenId must be outside the range of earlyBird period #2 IDs");

            await truffleAssert.reverts(nft.mintAdmin(991, owner), "tokenId must be outside the range of earlyBird period #3 IDs");
            await truffleAssert.reverts(nft.mintAdmin(997, owner), "tokenId must be outside the range of earlyBird period #3 IDs");
            await truffleAssert.reverts(nft.mintAdmin(999, owner), "tokenId must be outside the range of earlyBird period #3 IDs");

            await nft.setReserve(909, owner);
            await truffleAssert.reverts(nft.mintAdmin(909, owner), "the tokenId has been reserved");
            await nft.mintAdmin(301, owner);
            await truffleAssert.reverts(nft.mintAdmin(301, owner), "ERC721: token already minted");
            let tokenIds = await nft.walletOfOwner(owner);
            assert.equal(tokenIds.length, 1);
            assert.equal(tokenIds[0], 301);
        });

        it("check for angelMint", async () => {
            await nft.setAngelRoot(angelRoot.getHexRoot());

            let merkleProof_0 = angelRoot.getHexProof("0x" + keccak256(accounts[0]).toString('hex'));
            let merkleProof_1 = angelRoot.getHexProof("0x" + keccak256(accounts[1]).toString('hex'));

            await truffleAssert.reverts(nft.angelMint(2, merkleProof_0, {from:accounts[3]}), "AngelSale not active");

            await truffleAssert.reverts(nft.setAngelSale(true), "ANGEL_SUPPLY has not been set");
            await nft.setAngelSupply(300)
            await truffleAssert.reverts(nft.setAngelSale(true), "angelBeginId has not been set");
            await nft.setAngelBeginId(1000) // 1000 ~ 1299
            await nft.setAngelSale(true)
            await truffleAssert.reverts(nft.angelMint(0, merkleProof_0, {from:accounts[3]}), "quantity must be greater than 0");

            await truffleAssert.reverts(nft.angelMint(301, merkleProof_1, {from:accounts[0]}), "Not enough ANGEL_SUPPLY");
            await truffleAssert.reverts(nft.angelMint(2, merkleProof_1, {from:accounts[0]}), "Address is not in angel list");

            await truffleAssert.reverts(nft.angelMint(2, merkleProof_0, {from:accounts[0]}), "the number of caller mint exceeds the upper limit");
            await nft.setAngelMintLimit(accounts[0], 1);
            await nft.angelMint(1, merkleProof_0, {from:accounts[0]});
            await truffleAssert.reverts(nft.angelMint(1, merkleProof_0, {from:accounts[0]}), "the number of caller mint exceeds the upper limit");
            
            await nft.setAngelMintLimit(accounts[1], 2);

            await truffleAssert.reverts(nft.angelMint(3, merkleProof_1, {from:accounts[1]}), "the number of caller mint exceeds the upper limit");
            await nft.angelMint(1, merkleProof_1, {from:accounts[1]});
            await nft.angelMint(1, merkleProof_1, {from:accounts[1]});
            await truffleAssert.reverts(nft.angelMint(1, merkleProof_1, {from:accounts[1]}), "the number of caller mint exceeds the upper limit");

            assert.equal((await nft.currentAngelTokenId()).toNumber(), 1003);
            assert.equal((await nft.angelSaleCount()).toNumber(), 3);
            assert.equal((await nft.angelMintLimit(accounts[1])).toNumber(), 2);
            assert.equal((await nft.angelMintCount(accounts[1])).toNumber(), 2);

        });

        it("check for earlyBirdMint_1", async () => {
            await nft.setEarlyBirdRoot_1(earlybirdRoot.getHexRoot());

            let merkleProof_3 = earlybirdRoot.getHexProof("0x" + keccak256(accounts[3]).toString('hex'));

            await truffleAssert.reverts(nft.earlyBirdMint_1(1, merkleProof_3, {from:accounts[3]}), "EarlyBirdSale not active");
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "EARLYBIRD_SUPPLY_1 has not been set");
            await nft.setEarlyBirdSupply_1(300)
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "EARLYBIRD_SUPPLY_2 has not been set");
            await nft.setEarlyBirdSupply_2(9)
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "EARLYBIRD_SUPPLY_3 has not been set");
            await nft.setEarlyBirdSupply_3(9)
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "earlyBirdBeginId_2 has not been set");
            await nft.setAngelSupply(300)
            await nft.setAngelBeginId(1) // 1 ~ 300
            await nft.setEarlyBirdSupply_2(9)
            await nft.setEarlyBirdBeginId_2(982) // 982 ~ 990
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "earlyBirdBeginId_3 has not been set");
            await nft.setEarlyBirdSupply_3(9)
            await nft.setEarlyBirdBeginId_3(991) // 991 ~ 999
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "the start tokenId has not been set");
            await nft.setBeginId(301)
            await nft.setEarlyBirdSale(true)

            await truffleAssert.reverts(nft.earlyBirdMint_1(0, merkleProof_3, {from:accounts[4]}), "quantity must be greater than 0");
            await truffleAssert.reverts(nft.earlyBirdMint_1(319, merkleProof_3, {from:accounts[4]}), "Not enough EARLYBIRD_SUPPLY");
            await truffleAssert.reverts(nft.earlyBirdMint_1(1, merkleProof_3, {from:accounts[4]}), "Address is not in earlybird list");
            await truffleAssert.reverts(nft.earlyBirdMint_1(1, merkleProof_3, {from:accounts[3]}), "the number of caller mint exceeds the upper limit");
            await nft.setEarlyBirdMintLimit_1(accounts[3], 2);

            assert.equal((await nft.earlyBirdSaleCount()).toNumber(), 0);
            assert.equal((await nft.currentTokenId()).toNumber(), 301);

            await nft.mintAdmin(301, owner);
            await nft.mintAdmin(302, owner);
            
            await nft.earlyBirdMint_1(2, merkleProof_3, {from:accounts[3]});
            
            assert.equal((await nft.earlyBirdSaleCount()).toNumber(), 2);
            let tokenIds = await nft.walletOfOwner(accounts[3]);
            assert.equal(tokenIds.length, 2);
            assert.equal(tokenIds[0], 303);
            assert.equal(tokenIds[1], 304);
        });

        it("check for earlyBirdMint_2", async () => {
            await nft.setEarlyBirdRoot_2(earlybirdRoot.getHexRoot());

            let merkleProof_3 = earlybirdRoot.getHexProof("0x" + keccak256(accounts[3]).toString('hex'));

            await truffleAssert.reverts(nft.earlyBirdMint_2(1, merkleProof_3, {from:accounts[3]}), "EarlyBirdSale not active");
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "EARLYBIRD_SUPPLY_1 has not been set");
            await nft.setEarlyBirdSupply_1(300)
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "EARLYBIRD_SUPPLY_2 has not been set");
            await nft.setEarlyBirdSupply_2(9)
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "EARLYBIRD_SUPPLY_3 has not been set");
            await nft.setEarlyBirdSupply_3(9)
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "earlyBirdBeginId_2 has not been set");
            await nft.setAngelSupply(300)
            await nft.setAngelBeginId(1) // 1 ~ 300
            await nft.setEarlyBirdSupply_2(9)
            await nft.setEarlyBirdBeginId_2(982) // 982 ~ 990
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "earlyBirdBeginId_3 has not been set");
            await nft.setEarlyBirdSupply_3(9)
            await nft.setEarlyBirdBeginId_3(991) // 991 ~ 999
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "the start tokenId has not been set");
            await nft.setBeginId(301)
            await nft.setEarlyBirdSale(true)

            await truffleAssert.reverts(nft.earlyBirdMint_2(0, merkleProof_3, {from:accounts[4]}), "quantity must be greater than 0");
            await truffleAssert.reverts(nft.earlyBirdMint_2(319, merkleProof_3, {from:accounts[4]}), "Not enough EARLYBIRD_SUPPLY");
            await truffleAssert.reverts(nft.earlyBirdMint_2(1, merkleProof_3, {from:accounts[4]}), "Address is not in earlybird list");
            await truffleAssert.reverts(nft.earlyBirdMint_2(1, merkleProof_3, {from:accounts[3]}), "the number of caller mint exceeds the upper limit");
            await nft.setEarlyBirdMintLimit_2(accounts[3], 2);

            assert.equal((await nft.earlyBirdSaleCount()).toNumber(), 0);
            assert.equal((await nft.currentEarlyBirdTokenId_2()).toNumber(), 982);

            
            await nft.earlyBirdMint_2(2, merkleProof_3, {from:accounts[3]});
            
            assert.equal((await nft.earlyBirdSaleCount()).toNumber(), 2);
            let tokenIds = await nft.walletOfOwner(accounts[3]);
            assert.equal(tokenIds.length, 2);
            assert.equal(tokenIds[0], 982);
            assert.equal(tokenIds[1], 983);
            assert.equal((await nft.currentEarlyBirdTokenId_2()).toNumber(), 984);
        });

        it("check for earlyBirdMint_3", async () => {
            await nft.setEarlyBirdRoot_3(earlybirdRoot.getHexRoot());

            let merkleProof_3 = earlybirdRoot.getHexProof("0x" + keccak256(accounts[3]).toString('hex'));

            await truffleAssert.reverts(nft.earlyBirdMint_3(1, merkleProof_3, {from:accounts[3]}), "EarlyBirdSale not active");
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "EARLYBIRD_SUPPLY_1 has not been set");
            await nft.setEarlyBirdSupply_1(300)
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "EARLYBIRD_SUPPLY_2 has not been set");
            await nft.setEarlyBirdSupply_2(9)
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "EARLYBIRD_SUPPLY_3 has not been set");
            await nft.setEarlyBirdSupply_3(9)
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "earlyBirdBeginId_2 has not been set");
            await nft.setAngelSupply(300)
            await nft.setAngelBeginId(1) // 1 ~ 300
            await nft.setEarlyBirdSupply_2(9)
            await nft.setEarlyBirdBeginId_2(982) // 982 ~ 990
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "earlyBirdBeginId_3 has not been set");
            await nft.setEarlyBirdSupply_3(9)
            await nft.setEarlyBirdBeginId_3(991) // 991 ~ 999
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "the start tokenId has not been set");
            await nft.setBeginId(301)
            await nft.setEarlyBirdSale(true)

            await truffleAssert.reverts(nft.earlyBirdMint_3(0, merkleProof_3, {from:accounts[4]}), "quantity must be greater than 0");
            await truffleAssert.reverts(nft.earlyBirdMint_3(319, merkleProof_3, {from:accounts[4]}), "Not enough EARLYBIRD_SUPPLY");
            await truffleAssert.reverts(nft.earlyBirdMint_3(1, merkleProof_3, {from:accounts[4]}), "Address is not in earlybird list");
            await truffleAssert.reverts(nft.earlyBirdMint_3(1, merkleProof_3, {from:accounts[3]}), "the number of caller mint exceeds the upper limit");
            await nft.setEarlyBirdMintLimit_3(accounts[3], 2);

            assert.equal((await nft.earlyBirdSaleCount()).toNumber(), 0);
            assert.equal((await nft.currentEarlyBirdTokenId_3()).toNumber(), 991);

            
            await nft.earlyBirdMint_3(2, merkleProof_3, {from:accounts[3]});
            
            assert.equal((await nft.earlyBirdSaleCount()).toNumber(), 2);
            let tokenIds = await nft.walletOfOwner(accounts[3]);
            assert.equal(tokenIds.length, 2);
            assert.equal(tokenIds[0], 991);
            assert.equal(tokenIds[1], 992);
            assert.equal((await nft.currentEarlyBirdTokenId_3()).toNumber(), 993);
        });

        it("check for presaleMint", async () => {
            await nft.setPresaleRoot(presaleRoot.getHexRoot());

            let merkleProof_6 = presaleRoot.getHexProof("0x" + keccak256(accounts[6]).toString('hex'));

            await truffleAssert.reverts(nft.presaleMint(1, merkleProof_6, {from:accounts[6]}), "PreSale not active");
            await truffleAssert.reverts(nft.setPreSale(true), "PRE_SUPPLY has not been set");
            await nft.setPreSupply(300)
            await truffleAssert.reverts(nft.setPreSale(true), "the start tokenId has not been set");
            await nft.setAngelSupply(300)
            await nft.setAngelBeginId(1) // 1 ~ 300
            await nft.setBeginId(301)
            await truffleAssert.reverts(nft.setPreSale(true), "public price has not been set");
            await nft.setPublicPrice(ethers.utils.parseEther("0.001"))
            await nft.setPreSale(true)

            await truffleAssert.reverts(nft.presaleMint(301, merkleProof_6, {from:accounts[7]}), "Not enough PRE_SUPPLY");
            await truffleAssert.reverts(nft.presaleMint(1, merkleProof_6, {from:accounts[7]}), "Not enough ETH");
            let price = await nft.publicPrice();
            await truffleAssert.reverts(nft.presaleMint(1, merkleProof_6, {from:accounts[7], value:price}), "Address is not in presale list");

            assert.equal((await nft.preSaleCount()).toNumber(), 0);
            assert.equal((await nft.currentTokenId()).toNumber(), 301);
            await nft.setEarlyBirdSupply_2(9)
            await nft.setEarlyBirdBeginId_2(982) // 982 ~ 990
            await nft.setEarlyBirdSupply_3(9)
            await nft.setEarlyBirdBeginId_3(991) // 991 ~ 999
            await nft.mintAdmin(301, owner);
            await nft.mintAdmin(303, owner);
            
            await nft.presaleMint(2, merkleProof_6, {from:accounts[6], value:price * 2});
            
            assert.equal((await nft.preSaleCount()).toNumber(), 2);
            let tokenIds = await nft.walletOfOwner(accounts[6]);
            assert.equal(tokenIds.length, 2);
            assert.equal(tokenIds[0], 302);
            assert.equal(tokenIds[1], 304);
        });

        it("check for publicMint", async () => {

            await truffleAssert.reverts(nft.publicMint(1), "PublicSale not active");
            await truffleAssert.reverts(nft.setPublicSale(true), "PUBLI_SUPPLY has not been set");
            await nft.setPublicSupply(100)
            await truffleAssert.reverts(nft.setPublicSale(true), "the start tokenId has not been set");
            await nft.setAngelSupply(300)
            await nft.setAngelBeginId(1) // 1 ~ 300
            await nft.setBeginId(301)
            await truffleAssert.reverts(nft.setPublicSale(true), "public price has not been set");
            await nft.setPublicPrice(ethers.utils.parseEther("0.001"))
            await nft.setPublicSale(true)
            await truffleAssert.reverts(nft.publicMint(101), "Not enough PUBLI_SUPPLY");
            await truffleAssert.reverts(nft.publicMint(1), "Not enough ETH");

            let price = await nft.publicPrice();

            assert.equal((await nft.publicSaleCount()).toNumber(), 0);
            assert.equal((await nft.currentTokenId()).toNumber(), 301);
            await nft.setEarlyBirdSupply_2(9)
            await nft.setEarlyBirdBeginId_2(982) // 982 ~ 990
            await nft.setEarlyBirdSupply_3(9)
            await nft.setEarlyBirdBeginId_3(991) // 991 ~ 999
            await nft.mintAdmin(301, accounts[1]);
            await nft.mintAdmin(303, accounts[1]);

            await nft.publicMint(2,{value:price * 2});
            
            assert.equal((await nft.publicSaleCount()).toNumber(), 2);
            let tokenIds = await nft.walletOfOwner(owner);
            assert.equal(tokenIds.length, 2);
            assert.equal(tokenIds[0], 302);
            assert.equal(tokenIds[1], 304);
        });

        it("check for mintReserve", async () => {
            await nft.setAngelRoot(angelRoot.getHexRoot());
            await nft.setEarlyBirdRoot_1(earlybirdRoot.getHexRoot());
            await nft.setEarlyBirdRoot_2(earlybirdRoot.getHexRoot());
            await nft.setEarlyBirdRoot_3(earlybirdRoot.getHexRoot());
            await nft.setPresaleRoot(presaleRoot.getHexRoot());
            await nft.setAngelSupply(300)
            await nft.setAngelBeginId(1) // 1 ~ 300
            await nft.setEarlyBirdSupply_1(300)
            await nft.setEarlyBirdSupply_2(9)
            await nft.setEarlyBirdBeginId_2(982) // 982 ~ 990
            await nft.setEarlyBirdSupply_3(9)
            await nft.setEarlyBirdBeginId_3(991) // 991 ~ 999
            await nft.setBeginId(301)

            await nft.setPreSupply(300);
            await nft.setPublicSupply(100);

            await nft.setPublicPrice(ethers.utils.parseEther("0.001"))
            await nft.setAngelSale(true)
            await nft.setEarlyBirdSale(true)
            await nft.setPreSale(true)
            await nft.setPublicSale(true)


            await nft.mintAdmin(301,owner);
            await truffleAssert.reverts(nft.setReserve(301,owner), "tokenId already exists");
            await nft.setReserve(302,owner);
            await truffleAssert.reverts(nft.mintReserve(302, {from:accounts[1]}), "the tokenId does not belong to you");

            assert.equal((await nft.earlyBirdSaleCount()).toNumber(), 0);
            await nft.mintReserve(302)
            assert.equal((await nft.earlyBirdSaleCount()).toNumber(), 1);
            await truffleAssert.reverts(nft.mintReserve(302), "ERC721: token already minted");

            

            let price = await nft.publicPrice();
            let merkleProof_3 = earlybirdRoot.getHexProof("0x" + keccak256(accounts[3]).toString('hex'));
            let merkleProof_6 = presaleRoot.getHexProof("0x" + keccak256(accounts[6]).toString('hex'));

            await nft.setReserve(303,owner);
            await nft.setReserve(304,owner);
            await nft.setReserve(305,owner);

            await nft.setEarlyBirdMintLimit_1(accounts[3], 1);
            await nft.earlyBirdMint_1(1, merkleProof_3, {from:accounts[3]});
            
            assert.equal((await nft.ownerOf(306)), accounts[3]);
            assert.equal((await nft.balanceOf(accounts[3])).toNumber(), 1);

            await nft.presaleMint(1, merkleProof_6, {from:accounts[6],value:price});
            assert.equal((await nft.ownerOf(307)), accounts[6]);
            assert.equal((await nft.balanceOf(accounts[6])).toNumber(), 1);

            await nft.publicMint(1, {from:accounts[7],value:price});
            assert.equal((await nft.ownerOf(308)), accounts[7]);
            assert.equal((await nft.balanceOf(accounts[7])).toNumber(), 1);

            
        });
    });

    describe('check for ChampionNFTBridge',() => {
        let nft = null;
        let bridge = null;
        let whitelistAddresses = [accounts[0],accounts[1],accounts[2]];
        let options = {
            hashLeaves: true,
            sort:true,
            duplicateOdd: false,
            isBitcoinTree: false
        }
        const merkleTree = new MerkleTree(whitelistAddresses, keccak256, options)
        const owner = accounts[0];
        const validator = accounts[1];
        const sender = accounts[9];
        const _initBaseURI = "http://base.uri/"
        const _initNotRevealedUri = "http://notrevealed.uri/"
        const _pickupUri = "http://pickup.uri/";
        const address_0 = "0x0000000000000000000000000000000000000000";
        const testHash = "0x22b0cd6ada3c39f96328f2067ed876a444050e3abdfea2a7080f07323f675ba1";
        
        beforeEach(async function () {
            nft = await EsportsBoyNFT.new("Champion-nft", "CNFT", _initBaseURI, _initNotRevealedUri, _pickupUri);
            bridge = await EsportsBoyBridge.new();
            await bridge.__initialize(nft.address, 1000);
            await nft.setBridge(bridge.address);
        });


        it("check for addValidator removeValidator", async () => {
            assert.equal(await bridge.validatorCount(), 0);
            assert.equal(await bridge.isValidator(validator), false);
            await bridge.addValidator(validator);
            await truffleAssert.reverts(bridge.addValidator(address_0), "Validator address should not be 0x0");
            await truffleAssert.reverts(bridge.addValidator(owner), "Validator address should not be owner");
            await truffleAssert.reverts(bridge.addValidator(validator), "New validator should be an existing validator");

            assert.equal(await bridge.validatorCount(), 1);
            assert.equal(await bridge.isValidator(validator), true);
            await truffleAssert.reverts(bridge.removeValidator(owner), "Cannot remove address that is not a validator");
            await bridge.removeValidator(validator);

            assert.equal(await bridge.isValidator(validator), false);
            assert.equal(await bridge.validatorCount(), 0);
        });

        it("check for setRequiredSignatures", async () => {
            assert.equal(await bridge.requiredSignatures(), 0);
            await truffleAssert.reverts(bridge.setRequiredSignatures(1), "New requiredSignatures should be greater than num of validators");
            await truffleAssert.reverts(bridge.setRequiredSignatures(0), "New requiredSignatures should be > than 0");
            
            await bridge.addValidator(validator);
            await bridge.setRequiredSignatures(1);

            await truffleAssert.reverts(bridge.removeValidator(validator), "Removing validator should not make validator count be < requiredSignatures");
            await bridge.addValidator(accounts[2]);
            await bridge.removeValidator(validator);
        });

        it("check for delivery validator 1", async () => {
            await nft.setAngelSupply(300)
            await nft.setAngelBeginId(1) // 1 ~ 300
            await nft.setEarlyBirdSupply_2(9)
            await nft.setEarlyBirdBeginId_2(982) // 982 ~ 990
            await nft.setEarlyBirdSupply_3(9)
            await nft.setEarlyBirdBeginId_3(991) // 991 ~ 999



            await bridge.addValidator(validator);
            await bridge.setRequiredSignatures(1);
            var signature = await sign(validator, sender, 301, 900, testHash, bridge.address);
            
            await truffleAssert.reverts(bridge.delivery(sender, 301, 900, testHash, signature.substring(2)), "caller is not a validator");
            await truffleAssert.reverts(bridge.delivery(sender, 301, 900, testHash, signature.substring(2), {from: validator}), "ERC721: owner query for nonexistent token");
            await nft.mintAdmin(301, sender)
            await nft.setDelivered(301, true)
            await truffleAssert.reverts(bridge.delivery(owner, 301, 900, testHash, signature.substring(2), {from: validator}), "the tokenId does not belong to sender");
            await truffleAssert.reverts(bridge.delivery(sender, 301, 900, testHash, signature.substring(2), {from: validator}), "the tokenId has been delivered");
            await nft.setDelivered(301, false)
            await truffleAssert.reverts(bridge.delivery(sender, 301, 0, testHash, signature.substring(2), {from: validator}), "signature verify failed");
            await truffleAssert.reverts(bridge.delivery(sender, 301, 900, testHash, signature.substring(2), {from: validator}), "not enough medals to delivery");
            
            var signature = await sign(validator, sender, 301, 1000, testHash, bridge.address);
            await bridge.delivery(sender, 301, 1000, testHash, signature.substring(2), {from: validator})

            let isdelivered = await nft.isDelivered(301);
            assert.equal(isdelivered, true);
        });

        it("check for delivery validator 2", async () => {
            await nft.setAngelSupply(300)
            await nft.setAngelBeginId(1) // 1 ~ 300
            await nft.setEarlyBirdSupply_2(9)
            await nft.setEarlyBirdBeginId_2(982) // 982 ~ 990
            await nft.setEarlyBirdSupply_3(9)
            await nft.setEarlyBirdBeginId_3(991) // 991 ~ 999

            let validator2 = accounts[2];
            await bridge.addValidator(validator);
            await bridge.addValidator(validator2);
            await bridge.setRequiredSignatures(2);
            await nft.mintAdmin(301, sender);

            var signature = await sign(validator, sender, 301, 1000, testHash, bridge.address);
            await bridge.delivery(sender, 301, 1000, testHash, signature.substring(2), {from: validator})

            var isdelivered = await nft.isDelivered(301);
            assert.equal(isdelivered, false);

            var signature2 = await sign(validator2, sender, 301, 1000, testHash, bridge.address);
            await bridge.delivery(sender, 301, 1000, testHash, signature2.substring(2), {from: validator2})
            var isdelivered = await nft.isDelivered(301);
            assert.equal(isdelivered, true);
        });
    });
});