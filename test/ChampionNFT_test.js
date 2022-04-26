const { expect, assert } = require('chai');
const truffleAssert = require('truffle-assertions');
const { ethers } = require('ethers');
const { MerkleTree } = require('merkletreejs')
const keccak256 = require('keccak256')
// Load compiled artifacts
const EsportsBoyNFT = artifacts.require("EsportsBoyNFT");
const ChampionNFTBridge = artifacts.require("ChampionNFTBridge");
const { sign } = require("./utils/mint");

// Start test block
contract('EsportsBoyNFT Test', function (accounts) {
    
    describe('check for EsportsBoyNFT',() => {
        let nft = null;
        let bridge = null;
        let angleAddresses = [accounts[0],accounts[1],accounts[2]];
        let earlybirdAddresses = [accounts[3],accounts[4],accounts[5]];
        let presaleAddresses = [accounts[6],accounts[7],accounts[8]];
        let options = {
            hashLeaves: true,
            sort:true,
            duplicateOdd: false,
            isBitcoinTree: false
        }
        const angleRoot = new MerkleTree(angleAddresses, keccak256, options)
        const earlybirdRoot = new MerkleTree(earlybirdAddresses, keccak256, options)
        const presaleRoot = new MerkleTree(presaleAddresses, keccak256, options)
        const owner = accounts[0];
        const _initBaseURI = "http://base.uri/"
        const _initNotRevealedUri = "http://notrevealed.uri/"
        const _pickupUri = "http://pickup.uri/";

        const address_0 = "0x0000000000000000000000000000000000000000";
        
        beforeEach(async function () {
            nft = await EsportsBoyNFT.new("Champion-nft", "CNFT", _initBaseURI, _initNotRevealedUri, _pickupUri);
            bridge = await ChampionNFTBridge.new();
            await bridge.__initialize(nft.address, 1000, 1100);
            await nft.setBridge(bridge.address);
        });

        it("check for init", async () => {
            assert.equal(await nft.name(), "Champion-nft");
            assert.equal(await nft.symbol(), "CNFT");
        });

        it("check for set setAngleBeginId", async () => {
            await truffleAssert.reverts(nft.setAngleBeginId(0), "tokenId must be greater than 0");
            await truffleAssert.reverts(nft.setAngleBeginId(1000), "ANGEL_SUPPLY has not been set");
            await nft.setAngelSupply(300)
            await nft.setAngleBeginId(1000)

            assert.equal((await nft.angleBeginId()).toNumber(), 1000);
            assert.equal((await nft.currentAngleTokenId()).toNumber(), 1000);
        });

        // it("check for set setEarlyBridBeginId", async () => {
        //     await truffleAssert.reverts(nft.setEarlyBridBeginId(0), "tokenId must be greater than 0");
        //     await truffleAssert.reverts(nft.setEarlyBridBeginId(1000), "EARLYBIRD_SUPPLY has not been set");
        //     await nft.setEarlyBirdSupply(300)
        //     await truffleAssert.reverts(nft.setEarlyBridBeginId(1000), "angleBeginId has not been set");
        //     await nft.setAngelSupply(300)
        //     await nft.setAngleBeginId(1000)
        //     await truffleAssert.reverts(nft.setEarlyBridBeginId(1299), "earlyBridBeginId must be greater than the last angle period tokenId");
        //     await nft.setEarlyBridBeginId(1300)

        //     assert.equal((await nft.earlyBridBeginId()).toNumber(), 1300);
        //     assert.equal((await nft.currentEarlyBridTokenId()).toNumber(), 1300);
        // });

        it("check for set setBeginId", async () => {
            await truffleAssert.reverts(nft.setBeginId(0), "tokenId must be greater than 0");
            await truffleAssert.reverts(nft.setBeginId(1000), "angleBeginId has not been set");

            await nft.setAngelSupply(300)
            await nft.setAngleBeginId(1000) // 1000 ~ 1299

            await truffleAssert.reverts(nft.setBeginId(1299), "beginId must be greater than the last angle period tokenId");
            await nft.setBeginId(1300)

            assert.equal((await nft.currentTokenId()).toNumber(), 1300);
        });

        it("check for set setReserve", async () => {
            await truffleAssert.reverts(nft.setReserve(0, owner), "angleBeginId has not been set");
            await nft.setAngelSupply(300)
            await nft.setAngleBeginId(1000) // 1000 ~ 1299
            await nft.mintAdmin(1, owner);
            await truffleAssert.reverts(nft.setReserve(1, owner), "tokenId already exists");

            await truffleAssert.reverts(nft.setReserve(1000, owner), "tokenId must be outside the range of angel period IDs");
            await truffleAssert.reverts(nft.setReserve(1210, owner), "tokenId must be outside the range of angel period IDs");
            await truffleAssert.reverts(nft.setReserve(1299, owner), "tokenId must be outside the range of angel period IDs");
            await nft.setReserve(999, owner);
            await nft.setReserve(1300, owner);
        });
 
        it("check for tokenURI", async () => {
            await nft.setAngelSupply(300)
            await nft.setAngleBeginId(1000) // 1000 ~ 1299

            await truffleAssert.reverts(nft.tokenURI(1), "ERC721Metadata: URI query for nonexistent token");
            await nft.mintAdmin(1, owner)
            var url = await nft.tokenURI(1);
            assert.equal(url, _initNotRevealedUri);

            await nft.setRevealed(true);
            var url = await nft.tokenURI(1);
            assert.equal(url, _initBaseURI + "1");

            await truffleAssert.reverts(nft.setDelivered(1, true, {from:accounts[1]}), "caller neither owner nor bridge");
            await nft.setDelivered(1, true);
            var url = await nft.tokenURI(1);
            assert.equal(url, _pickupUri + "1"); 
        });

        it("check for set mintAdmin ", async () => {
            await truffleAssert.reverts(nft.mintAdmin(0, owner), "angleBeginId has not been set");
            await nft.setAngelSupply(300)
            await nft.setAngleBeginId(1000) // 1000 ~ 1299
            await nft.mintAdmin(1, owner);
            await truffleAssert.reverts(nft.mintAdmin(1, owner), "ERC721: token already minted");

            await truffleAssert.reverts(nft.mintAdmin(1000, owner), "tokenId must be outside the range of angel period IDs");
            await truffleAssert.reverts(nft.mintAdmin(1210, owner), "tokenId must be outside the range of angel period IDs");
            await truffleAssert.reverts(nft.mintAdmin(1299, owner), "tokenId must be outside the range of angel period IDs");

            await nft.setReserve(999, owner);
            await truffleAssert.reverts(nft.mintAdmin(999, owner), "the tokenId has been reserved");
            await nft.mintAdmin(1300, owner);
            let tokenIds = await nft.walletOfOwner(owner);
            assert.equal(tokenIds.length, 2);
            assert.equal(tokenIds[0], 1);
            assert.equal(tokenIds[1], 1300);
        });

        it("check for angleMint", async () => {
            await nft.setAngleRoot(angleRoot.getHexRoot());

            let merkleProof_0 = angleRoot.getHexProof("0x" + keccak256(accounts[0]).toString('hex'));
            let merkleProof_1 = angleRoot.getHexProof("0x" + keccak256(accounts[1]).toString('hex'));

            await truffleAssert.reverts(nft.angleMint(2, merkleProof_0, {from:accounts[3]}), "AngleSale not active");

            await truffleAssert.reverts(nft.setAngleSale(true), "ANGEL_SUPPLY has not been set");
            await nft.setAngelSupply(300)
            await truffleAssert.reverts(nft.setAngleSale(true), "angleBeginId has not been set");
            await nft.setAngleBeginId(1000) // 1000 ~ 1299
            await nft.setAngleSale(true)
            await truffleAssert.reverts(nft.angleMint(0, merkleProof_0, {from:accounts[3]}), "quantity must be greater than 0");

            await truffleAssert.reverts(nft.angleMint(301, merkleProof_1, {from:accounts[0]}), "Not enough ANGEL_SUPPLY");
            await truffleAssert.reverts(nft.angleMint(2, merkleProof_1, {from:accounts[0]}), "Address is not in angle list");

            await truffleAssert.reverts(nft.angleMint(2, merkleProof_0, {from:accounts[0]}), "the number of caller mint exceeds the upper limit");
            await nft.setAngleMintLimit(accounts[0], 1);
            await nft.angleMint(1, merkleProof_0, {from:accounts[0]});
            await truffleAssert.reverts(nft.angleMint(1, merkleProof_0, {from:accounts[0]}), "the number of caller mint exceeds the upper limit");
            
            await nft.setAngleMintLimit(accounts[1], 2);

            await truffleAssert.reverts(nft.angleMint(3, merkleProof_1, {from:accounts[1]}), "the number of caller mint exceeds the upper limit");
            await nft.angleMint(1, merkleProof_1, {from:accounts[1]});
            await nft.angleMint(1, merkleProof_1, {from:accounts[1]});
            await truffleAssert.reverts(nft.angleMint(1, merkleProof_1, {from:accounts[1]}), "the number of caller mint exceeds the upper limit");

            assert.equal((await nft.currentAngleTokenId()).toNumber(), 1003);
            assert.equal((await nft.angleSaleCount()).toNumber(), 3);
            assert.equal((await nft.angleMintLimit(accounts[1])).toNumber(), 2);
            assert.equal((await nft.angleMintCount(accounts[1])).toNumber(), 2);

        });

        it("check for earlyBridMint", async () => {
            await nft.setEarlyBirdRoot(earlybirdRoot.getHexRoot());

            let merkleProof_3 = earlybirdRoot.getHexProof("0x" + keccak256(accounts[3]).toString('hex'));

            await truffleAssert.reverts(nft.earlyBridMint(1, merkleProof_3, {from:accounts[3]}), "EarlyBirdSale not active");
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "EARLYBIRD_SUPPLY has not been set");
            await nft.setEarlyBirdSupply(300)
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "the start tokenId has not been set");
            await nft.setAngelSupply(300)
            await nft.setAngleBeginId(1000) // 1000 ~ 1299
            await nft.setBeginId(1300)
            await truffleAssert.reverts(nft.setEarlyBirdSale(true), "public price has not been set");
            await nft.setPublicPrice(ethers.utils.parseEther("0.001"))
            await nft.setEarlyBirdSale(true)

            await truffleAssert.reverts(nft.earlyBridMint(0, merkleProof_3, {from:accounts[4]}), "quantity must be greater than 0");
            await truffleAssert.reverts(nft.earlyBridMint(301, merkleProof_3, {from:accounts[4]}), "Not enough EARLYBIRD_SUPPLY");
            await truffleAssert.reverts(nft.earlyBridMint(1, merkleProof_3, {from:accounts[4]}), "Not enough ETH");
            let price = await nft.publicPrice();
            await truffleAssert.reverts(nft.earlyBridMint(1, merkleProof_3, {from:accounts[4], value:price}), "Address is not in earlybird list");

            assert.equal((await nft.earlyBridSaleCount()).toNumber(), 0);
            assert.equal((await nft.currentTokenId()).toNumber(), 1300);
            await nft.mintAdmin(1300, owner);
            await nft.mintAdmin(1302, owner);
            
            await nft.earlyBridMint(2, merkleProof_3, {from:accounts[3], value:price * 2});
            
            assert.equal((await nft.earlyBridSaleCount()).toNumber(), 2);
            let tokenIds = await nft.walletOfOwner(accounts[3]);
            assert.equal(tokenIds.length, 2);
            assert.equal(tokenIds[0], 1301);
            assert.equal(tokenIds[1], 1303);
        });

        it("check for presaleMint", async () => {
            await nft.setPresaleRoot(presaleRoot.getHexRoot());

            let merkleProof_6 = presaleRoot.getHexProof("0x" + keccak256(accounts[6]).toString('hex'));

            await truffleAssert.reverts(nft.presaleMint(1, merkleProof_6, {from:accounts[6]}), "PreSale not active");
            await truffleAssert.reverts(nft.setPreSale(true), "PRE_SUPPLY has not been set");
            await nft.setPreSupply(300)
            await truffleAssert.reverts(nft.setPreSale(true), "the start tokenId has not been set");
            await nft.setAngelSupply(300)
            await nft.setAngleBeginId(1000) // 1000 ~ 1299
            await nft.setBeginId(1300)
            await truffleAssert.reverts(nft.setPreSale(true), "public price has not been set");
            await nft.setPublicPrice(ethers.utils.parseEther("0.001"))
            await nft.setPreSale(true)

            await truffleAssert.reverts(nft.presaleMint(301, merkleProof_6, {from:accounts[7]}), "Not enough PRE_SUPPLY");
            await truffleAssert.reverts(nft.presaleMint(1, merkleProof_6, {from:accounts[7]}), "Not enough ETH");
            let price = await nft.publicPrice();
            await truffleAssert.reverts(nft.presaleMint(1, merkleProof_6, {from:accounts[7], value:price}), "Address is not in presale list");

            assert.equal((await nft.preSaleCount()).toNumber(), 0);
            assert.equal((await nft.currentTokenId()).toNumber(), 1300);
            await nft.mintAdmin(1300, owner);
            await nft.mintAdmin(1302, owner);
            
            await nft.presaleMint(2, merkleProof_6, {from:accounts[6], value:price * 2});
            
            assert.equal((await nft.preSaleCount()).toNumber(), 2);
            let tokenIds = await nft.walletOfOwner(accounts[6]);
            assert.equal(tokenIds.length, 2);
            assert.equal(tokenIds[0], 1301);
            assert.equal(tokenIds[1], 1303);
        });

        it("check for publicMint", async () => {

            await truffleAssert.reverts(nft.publicMint(1), "PublicSale not active");
            await truffleAssert.reverts(nft.setPublicSale(true), "PUBLI_SUPPLY has not been set");
            await nft.setPublicSupply(100)
            await truffleAssert.reverts(nft.setPublicSale(true), "the start tokenId has not been set");
            await nft.setAngelSupply(300)
            await nft.setAngleBeginId(1000) // 1000 ~ 1299
            await nft.setBeginId(1300)
            await truffleAssert.reverts(nft.setPublicSale(true), "public price has not been set");
            await nft.setPublicPrice(ethers.utils.parseEther("0.001"))
            await nft.setPublicSale(true)
            await truffleAssert.reverts(nft.publicMint(101), "Not enough PUBLI_SUPPLY");
            await truffleAssert.reverts(nft.publicMint(1), "Not enough ETH");

            let price = await nft.publicPrice();

            assert.equal((await nft.publicSaleCount()).toNumber(), 0);
            assert.equal((await nft.currentTokenId()).toNumber(), 1300);
            await nft.mintAdmin(1300, accounts[1]);
            await nft.mintAdmin(1302, accounts[1]);

            await nft.publicMint(2,{value:price * 2});
            
            assert.equal((await nft.publicSaleCount()).toNumber(), 2);
            let tokenIds = await nft.walletOfOwner(owner);
            assert.equal(tokenIds.length, 2);
            assert.equal(tokenIds[0], 1301);
            assert.equal(tokenIds[1], 1303);
        });

        it("check for mintReserve", async () => {
            await nft.setAngelSupply(300)
            await nft.setAngleBeginId(1000) // 1000 ~ 1299
            await nft.mintAdmin(1,owner);
            await truffleAssert.reverts(nft.setReserve(1,owner), "tokenId already exists");
            await nft.setReserve(2,owner);
            await truffleAssert.reverts(nft.mintReserve(1), "the tokenId does not belong to you");
            await nft.mintReserve(2)
            await truffleAssert.reverts(nft.mintReserve(2), "ERC721: token already minted");

            await nft.setAngleRoot(angleRoot.getHexRoot());
            await nft.setEarlyBirdRoot(earlybirdRoot.getHexRoot());
            await nft.setPresaleRoot(presaleRoot.getHexRoot());
            await nft.setAngelSupply(300)
            await nft.setAngleBeginId(1000) // 1000 ~ 1299
            await nft.setBeginId(1300)
            await nft.setAngleSale(true)
            await nft.setPublicPrice(ethers.utils.parseEther("0.001"))
            await nft.setEarlyBirdSupply(300)
            await nft.setEarlyBirdSale(true)
            await nft.setPreSupply(300)
            await nft.setPreSale(true)
            await nft.setPublicSupply(100)
            await nft.setPublicSale(true)

            let price = await nft.publicPrice();
            let merkleProof_3 = earlybirdRoot.getHexProof("0x" + keccak256(accounts[3]).toString('hex'));
            let merkleProof_6 = presaleRoot.getHexProof("0x" + keccak256(accounts[6]).toString('hex'));

            await nft.setReserve(1300,owner);
            await nft.setReserve(1302,owner);
            await nft.setReserve(1303,owner);

            await nft.earlyBridMint(1, merkleProof_3, {from:accounts[3],value:price});
            assert.equal((await nft.ownerOf(1301)), accounts[3]);
            assert.equal((await nft.balanceOf(accounts[3])).toNumber(), 1);

            await nft.presaleMint(1, merkleProof_6, {from:accounts[6],value:price});
            assert.equal((await nft.ownerOf(1304)), accounts[6]);
            assert.equal((await nft.balanceOf(accounts[6])).toNumber(), 1);

            await nft.publicMint(1, {from:accounts[7],value:price});
            assert.equal((await nft.ownerOf(1305)), accounts[7]);
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
            bridge = await ChampionNFTBridge.new();
            await bridge.__initialize(nft.address, 1000, 1100);
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

        it("check for setFirstBuy", async () => {
            assert.equal(await bridge.firstBuyMap(1), address_0);
            await truffleAssert.reverts(bridge.setFirstBuy(1, owner), "ERC721: owner query for nonexistent token");
            await nft.setAngelSupply(300)
            await nft.setAngleBeginId(1000) // 1000 ~ 1299
            await nft.mintAdmin(1, owner)
            await truffleAssert.reverts(bridge.setFirstBuy(1, validator), "the tokenId does not belong to account");
            assert.equal(await bridge.firstBuyMap(1), owner);
        });


        it("check for delivery validator 1", async () => {
            await bridge.addValidator(validator);
            await bridge.setRequiredSignatures(1);
            var signature = await sign(validator, sender, 1, 900, testHash, bridge.address);
            
            await truffleAssert.reverts(bridge.delivery(sender, 1, 900, testHash, signature.substring(2)), "caller is not a validator");
            await truffleAssert.reverts(bridge.delivery(sender, 1, 900, testHash, signature.substring(2), {from: validator}), "ERC721: owner query for nonexistent token");
            await nft.setAngelSupply(300)
            await nft.setAngleBeginId(1000) // 1000 ~ 1299
            await nft.mintAdmin(1, sender)
            await nft.setDelivered(1, true)
            await truffleAssert.reverts(bridge.delivery(owner, 1, 900, testHash, signature.substring(2), {from: validator}), "the tokenId does not belong to sender");
            await truffleAssert.reverts(bridge.delivery(sender, 1, 900, testHash, signature.substring(2), {from: validator}), "the tokenId has been delivered");
            await nft.setDelivered(1, false)
            await truffleAssert.reverts(bridge.delivery(sender, 1, 0, testHash, signature.substring(2), {from: validator}), "signature verify failed");
            await truffleAssert.reverts(bridge.delivery(sender, 1, 900, testHash, signature.substring(2), {from: validator}), "not enough medals to delivery - lv1");
            
            var signature = await sign(validator, sender, 1, 1000, testHash, bridge.address);
            await bridge.delivery(sender, 1, 1000, testHash, signature.substring(2), {from: validator})

            let isdelivered = await nft.isDelivered(1);
            assert.equal(isdelivered, true);
        });

        it("check for delivery validator 2", async () => {
            let validator2 = accounts[2];
            await bridge.addValidator(validator);
            await bridge.addValidator(validator2);
            await bridge.setRequiredSignatures(2);
            await nft.setAngelSupply(300)
            await nft.setAngleBeginId(1000) // 1000 ~ 1299
            await nft.mintAdmin(1, sender);

            var signature = await sign(validator, sender, 1, 1000, testHash, bridge.address);
            await bridge.delivery(sender, 1, 1000, testHash, signature.substring(2), {from: validator})

            var isdelivered = await nft.isDelivered(1);
            assert.equal(isdelivered, false);

            var signature2 = await sign(validator2, sender, 1, 1000, testHash, bridge.address);
            await bridge.delivery(sender, 1, 1000, testHash, signature2.substring(2), {from: validator2})
            var isdelivered = await nft.isDelivered(1);
            assert.equal(isdelivered, true);
        });

        it("check for delivery validator 1 not firstbuy", async () => {
            await bridge.addValidator(validator);
            await bridge.setRequiredSignatures(1);
            await nft.setAngelSupply(300)
            await nft.setAngleBeginId(1000) // 1000 ~ 1299
            await nft.mintAdmin(1, sender);
            await nft.transferFrom(sender, owner, 1, {from: sender});

            var signature = await sign(validator, owner, 1, 1000, testHash, bridge.address);
            await truffleAssert.reverts(bridge.delivery(owner, 1, 1000, testHash, signature.substring(2), {from: validator}), "not enough medals to delivery - lv2");

            var signature = await sign(validator, owner, 1, 1100, testHash, bridge.address);
            await bridge.delivery(owner, 1, 1100, testHash, signature.substring(2), {from: validator})

            var isdelivered = await nft.isDelivered(1);
            assert.equal(isdelivered, true);
        });
    });
});