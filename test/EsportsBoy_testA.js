const { expect, assert } = require('chai');
const truffleAssert = require('truffle-assertions');
const { ethers } = require('ethers');
const { MerkleTree } = require('merkletreejs')
const keccak256 = require('keccak256')
// Load compiled artifacts
const EsportsBoyNFTA = artifacts.require("EsportsBoyNFTA");
const EsportsBoyBridge = artifacts.require("EsportsBoyBridge");
const TUSDT = artifacts.require("TUSDT");

const { sign } = require("./utils/mint");

// Start test block
contract('EsportsBoyNFTA Test', function (accounts) {
    
    describe('check for EsportsBoyNFTA',() => {
        let nft = null;
        let usdt = null;
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
            usdt = await TUSDT.new("TEST USDT","TUSD");
            nft = await EsportsBoyNFTA.new("Champion-nft", "CNFT", _initBaseURI, _initNotRevealedUri, _pickupUri);
            bridge = await EsportsBoyBridge.new();
            await bridge.__initialize(nft.address, 1000);
            await nft.setBridge(bridge.address);
            await nft.setUSDT(usdt.address);
        });

        it("check for init", async () => {
            assert.equal(await nft.name(), "Champion-nft");
            assert.equal(await nft.symbol(), "CNFT");
        });
 
        it("check for tokenURI", async () => {
            await truffleAssert.reverts(nft.tokenURI(1), "ERC721Metadata: URI query for nonexistent token");


            let merkleProof_0 = angelRoot.getHexProof("0x" + keccak256(accounts[0]).toString('hex'));
            await nft.setAngelRoot(angelRoot.getHexRoot());
            await nft.setAngelMintLimit(accounts[0], 10);
            await nft.setAngelSale(true)
            await nft.angelMint(1, merkleProof_0, {from:accounts[0]});//#1


            var url = await nft.tokenURI(0);
            assert.equal(url, _initNotRevealedUri);

            await nft.setRevealed(true);
            var url = await nft.tokenURI(0);
            assert.equal(url, _initBaseURI + "0");

            await truffleAssert.reverts(nft.setDelivered(1, true, {from:accounts[1]}), "caller neither owner nor bridge");
            await nft.setDelivered(0, true);
            var url = await nft.tokenURI(0);
            assert.equal(url, _pickupUri + "0"); 
        });

        it("check for angelMint", async () => {
            await nft.setAngelRoot(angelRoot.getHexRoot());

            let merkleProof_0 = angelRoot.getHexProof("0x" + keccak256(accounts[0]).toString('hex'));
            let merkleProof_1 = angelRoot.getHexProof("0x" + keccak256(accounts[1]).toString('hex'));

            await truffleAssert.reverts(nft.angelMint(2, merkleProof_0, {from:accounts[3]}), "AngelSale not active");
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

            assert.equal((await nft.angelSaleCount()).toNumber(), 3);
            assert.equal((await nft.angelMintLimit(accounts[1])).toNumber(), 2);
            assert.equal((await nft.angelMintCount(accounts[1])).toNumber(), 2);

        });

        it("check for earlyBirdMint", async () => {
            let merkleProof_0 = angelRoot.getHexProof("0x" + keccak256(accounts[0]).toString('hex'));
            await nft.setAngelRoot(angelRoot.getHexRoot());
            await nft.setAngelMintLimit(accounts[0], 10);
            await nft.setAngelSale(true)

            await nft.setEarlyBirdRoot(earlybirdRoot.getHexRoot());

            let merkleProof_3 = earlybirdRoot.getHexProof("0x" + keccak256(accounts[3]).toString('hex'));

            await truffleAssert.reverts(nft.earlyBirdMint(1, merkleProof_3, {from:accounts[3]}), "EarlyBirdSale not active");
            await nft.setEarlyBirdSale(true)

            await truffleAssert.reverts(nft.earlyBirdMint(0, merkleProof_3, {from:accounts[4]}), "quantity must be greater than 0");
            await truffleAssert.reverts(nft.earlyBirdMint(319, merkleProof_3, {from:accounts[4]}), "Not enough EARLYBIRD_SUPPLY");
            await truffleAssert.reverts(nft.earlyBirdMint(1, merkleProof_3, {from:accounts[4]}), "Address is not in earlybird list");
            await truffleAssert.reverts(nft.earlyBirdMint(1, merkleProof_3, {from:accounts[3]}), "the number of caller mint exceeds the upper limit");
            await nft.setEarlyBirdMintLimit(accounts[3], 2);

            assert.equal((await nft.earlyBirdSaleCount()).toNumber(), 0);
            assert.equal((await nft.currentTokenId()).toNumber(), 0);

            //await nft.mintAdmin(owner, 1); //#1
            //await nft.mintAdmin(owner, 1); //#2
            await nft.angelMint(1, merkleProof_0, {from:accounts[0]});//#1
            await nft.angelMint(1, merkleProof_0, {from:accounts[0]});//#2
            
            await nft.earlyBirdMint(2, merkleProof_3, {from:accounts[3]});
            
            assert.equal((await nft.earlyBirdSaleCount()).toNumber(), 2);
            assert.equal((await nft.earlyBirdMintCount(accounts[3])).toNumber(), 2);

            let tokenIds = await nft.tokensOfOwner(accounts[3]);
            assert.equal(tokenIds.length, 2);
            assert.equal(tokenIds[0], 2);
            assert.equal(tokenIds[1], 3);
        });

        it("check for presaleMint", async () => {
            let merkleProof_0 = angelRoot.getHexProof("0x" + keccak256(accounts[0]).toString('hex'));
            await nft.setAngelRoot(angelRoot.getHexRoot());
            await nft.setAngelMintLimit(accounts[0], 10);
            await nft.setAngelSale(true)

            await nft.setPresaleRoot(presaleRoot.getHexRoot());

            let merkleProof_6 = presaleRoot.getHexProof("0x" + keccak256(accounts[6]).toString('hex'));

            await truffleAssert.reverts(nft.presaleMint(1, merkleProof_6, 0,{from:accounts[6]}), "PreSale not active");
            await truffleAssert.reverts(nft.setPreSale(true), "public price has not been set");
            await nft.setPublicPrice(ethers.utils.parseUnits("2",6)) //2 U
            await nft.setPreSale(true)

            await truffleAssert.reverts(nft.presaleMint(301, merkleProof_6, 0, {from:accounts[7]}), "Not enough PRE_SUPPLY");
            await truffleAssert.reverts(nft.presaleMint(1, merkleProof_6, 0, {from:accounts[7]}), "Address is not in presale list");
            await truffleAssert.reverts(nft.presaleMint(1, merkleProof_6, 0, {from:accounts[6]}), "the number of caller mint exceeds the upper limit");
            await nft.setPreSaleMintLimit(accounts[6], 2);

            await truffleAssert.reverts(nft.presaleMint(1, merkleProof_6, 0,{from:accounts[6]}), "amount is wrong");
            let price = await nft.publicPrice();
            await truffleAssert.reverts(nft.presaleMint(1, merkleProof_6, price, {from:accounts[6]}), "balanceOf usdt is not enough");

            assert.equal((await nft.preSaleCount()).toNumber(), 0);
            assert.equal((await nft.currentTokenId()).toNumber(), 0);
            await nft.angelMint(1, merkleProof_0, {from:accounts[0]});//#0
            await nft.angelMint(2, merkleProof_0, {from:accounts[0]});//#1 #2
            

            let pay_usdt = ethers.utils.parseUnits(price.toString(),'wei').mul(2);
            await usdt.transfer(accounts[6], pay_usdt);
            await truffleAssert.reverts(nft.presaleMint(2, merkleProof_6, pay_usdt, {from:accounts[6]}), "ERC20: insufficient allowance");
            await usdt.approve(nft.address, pay_usdt, {from:accounts[6]});
            await nft.presaleMint(2, merkleProof_6, pay_usdt, {from:accounts[6]});
            
            assert.equal((await nft.preSaleCount()).toNumber(), 2);
            assert.equal((await nft.preSaleMintCount(accounts[6])).toNumber(), 2);
            let tokenIds = await nft.tokensOfOwner(accounts[6]);
            assert.equal(tokenIds.length, 2);
            assert.equal(tokenIds[0], 3);
            assert.equal(tokenIds[1], 4);

            assert.equal((await usdt.balanceOf(nft.address)).toString(), ethers.utils.parseUnits(price.toString(),'wei').mul(2).toString());
        });

        it("check for publicMint", async () => {
            let merkleProof_0 = angelRoot.getHexProof("0x" + keccak256(accounts[0]).toString('hex'));
            await nft.setAngelRoot(angelRoot.getHexRoot());
            await nft.setAngelMintLimit(accounts[0], 10);
            await nft.setAngelSale(true)


            await truffleAssert.reverts(nft.publicMint(1,0), "PublicSale not active");
            await truffleAssert.reverts(nft.setPublicSale(true), "public price has not been set");
            await nft.setPublicPrice(ethers.utils.parseUnits("2",6)) //2 U
            await nft.setPublicSale(true)
            await truffleAssert.reverts(nft.publicMint(101, 0), "Not enough PUBLI_SUPPLY");
            await truffleAssert.reverts(nft.publicMint(1, 0), "amount is wrong");

            let price = await nft.publicPrice();

            assert.equal((await nft.publicSaleCount()).toNumber(), 0);
            assert.equal((await nft.currentTokenId()).toNumber(), 0);
            
            await nft.angelMint(1, merkleProof_0, {from:accounts[0]});//#0
            await nft.angelMint(2, merkleProof_0, {from:accounts[0]});//#1 #2
            

            let pay_usdt = ethers.utils.parseUnits(price.toString(),'wei').mul(2);
            await truffleAssert.reverts(nft.publicMint(2, pay_usdt), "ERC20: insufficient allowance");
            await usdt.approve(nft.address, pay_usdt);
            await nft.publicMint(2, pay_usdt);
            
            assert.equal((await nft.publicSaleCount()).toNumber(), 2);
            let tokenIds = await nft.tokensOfOwner(owner);
            assert.equal(tokenIds.length, 5);
            assert.equal(tokenIds[0], 0);
            assert.equal(tokenIds[1], 1);
            assert.equal(tokenIds[2], 2);
            assert.equal(tokenIds[3], 3);
            assert.equal(tokenIds[4], 4);
        });

        it("check for withdrawUSDT", async () => {
            let owner_balance = await usdt.balanceOf(owner);

            await nft.setPublicPrice(ethers.utils.parseUnits("2",6)) //2 U
            await nft.setPublicSale(true)

            let price = await nft.publicPrice();
            let pay_usdt = ethers.utils.parseUnits(price.toString(),'wei').mul(2);
            await usdt.approve(nft.address, pay_usdt);

            assert.equal((await usdt.balanceOf(nft.address)).toString(), "0");
            await nft.publicMint(2, pay_usdt);
            assert.equal((await usdt.balanceOf(nft.address)).toString(), pay_usdt.toString());
            
            await nft.withdrawUSDT();

            assert.equal((await usdt.balanceOf(nft.address)).toString(), "0");
            assert.equal((await usdt.balanceOf(owner)).toString(), owner_balance.toString());
        });
    });

    describe('check for ChampionNFTBridge',() => {
        let nft = null;
        let bridge = null;
        
        let angelAddresses = [accounts[0],accounts[1],accounts[9]];
        let options = {
            hashLeaves: true,
            sort:true,
            duplicateOdd: false,
            isBitcoinTree: false
        }
        const angelRoot = new MerkleTree(angelAddresses, keccak256, options)
        const owner = accounts[0];
        const validator = accounts[1];
        const sender = accounts[9];
        const _initBaseURI = "http://base.uri/"
        const _initNotRevealedUri = "http://notrevealed.uri/"
        const _pickupUri = "http://pickup.uri/";
        const address_0 = "0x0000000000000000000000000000000000000000";
        const testHash = "0x22b0cd6ada3c39f96328f2067ed876a444050e3abdfea2a7080f07323f675ba1";
        
        beforeEach(async function () {
            nft = await EsportsBoyNFTA.new("Champion-nft", "CNFT", _initBaseURI, _initNotRevealedUri, _pickupUri);
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
            await truffleAssert.reverts(bridge.setRequiredSignatures(1), "New requiredSignatures should be less than or equal to num of validators");
            await truffleAssert.reverts(bridge.setRequiredSignatures(0), "New requiredSignatures should be > than 0");
            
            await bridge.addValidator(validator);
            await bridge.setRequiredSignatures(1);

            await truffleAssert.reverts(bridge.removeValidator(validator), "Removing validator should not make validator count be < requiredSignatures");
            await bridge.addValidator(accounts[2]);
            await bridge.removeValidator(validator);
        });

        it("check for delivery validator 1", async () => {
            
            await bridge.addValidator(validator);
            await bridge.setRequiredSignatures(1);
            var signature = await sign(validator, sender, 0, 900, testHash, bridge.address);
            
            await truffleAssert.reverts(bridge.delivery(sender, 0, 900, testHash, signature.substring(2)), "caller is not a validator");
            await truffleAssert.reverts(bridge.delivery(sender, 0, 900, testHash, signature.substring(2), {from: validator}), "VM Exception while processing transaction: revert");

            let merkleProof_0 = angelRoot.getHexProof("0x" + keccak256(sender).toString('hex'));
            await nft.setAngelRoot(angelRoot.getHexRoot());
            await nft.setAngelMintLimit(sender, 10);
            await nft.setAngelSale(true)
            await nft.angelMint(1, merkleProof_0, {from:sender});//#0

            await nft.setDelivered(0, true)
            await truffleAssert.reverts(bridge.delivery(owner, 0, 900, testHash, signature.substring(2), {from: validator}), "the tokenId does not belong to sender");
            await truffleAssert.reverts(bridge.delivery(sender, 0, 900, testHash, signature.substring(2), {from: validator}), "the tokenId has been delivered");
            await nft.setDelivered(0, false)
            await truffleAssert.reverts(bridge.delivery(sender, 0, 0, testHash, signature.substring(2), {from: validator}), "signature verify failed");
            await truffleAssert.reverts(bridge.delivery(sender, 0, 900, testHash, signature.substring(2), {from: validator}), "not enough medals to delivery");
            
            var signature = await sign(validator, sender, 0, 1000, testHash, bridge.address);
            await bridge.delivery(sender, 0, 1000, testHash, signature.substring(2), {from: validator})

            let isdelivered = await nft.isDelivered(0);
            assert.equal(isdelivered, true);
        });

        it("check for delivery validator 2", async () => {
           
            let validator2 = accounts[2];
            await bridge.addValidator(validator);
            await bridge.addValidator(validator2);
            await bridge.setRequiredSignatures(2);

            let merkleProof_0 = angelRoot.getHexProof("0x" + keccak256(sender).toString('hex'));
            await nft.setAngelRoot(angelRoot.getHexRoot());
            await nft.setAngelMintLimit(sender, 10);
            await nft.setAngelSale(true)
            await nft.angelMint(1, merkleProof_0, {from:sender});//#0


            var signature = await sign(validator, sender, 0, 1000, testHash, bridge.address);
            await bridge.delivery(sender, 0, 1000, testHash, signature.substring(2), {from: validator})

            var isdelivered = await nft.isDelivered(0);
            assert.equal(isdelivered, false);

            var signature2 = await sign(validator2, sender, 0, 1000, testHash, bridge.address);
            await bridge.delivery(sender, 0, 1000, testHash, signature2.substring(2), {from: validator2})
            var isdelivered = await nft.isDelivered(0);
            assert.equal(isdelivered, true);
        });
    });
});