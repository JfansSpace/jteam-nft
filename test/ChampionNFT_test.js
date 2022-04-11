const { expect, assert } = require('chai');
const truffleAssert = require('truffle-assertions');
const { ethers } = require('ethers');
const { MerkleTree } = require('merkletreejs')
const keccak256 = require('keccak256')
// Load compiled artifacts
const ChampionNFT = artifacts.require("ChampionNFT");
const ChampionNFTBridge = artifacts.require("ChampionNFTBridge");
const { sign } = require("./utils/mint");

// Start test block
contract('ChampionNFT Test', function (accounts) {
    
    describe('check for ChampionNFT',() => {
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
        const _initBaseURI = "http://base.uri/"
        const _initNotRevealedUri = "http://notrevealed.uri/"
        const _pickupUri = "http://pickup.uri/";

        const address_0 = "0x0000000000000000000000000000000000000000";
        
        beforeEach(async function () {
            nft = await ChampionNFT.new("Champion-nft", "CNFT", _initBaseURI, _initNotRevealedUri, _pickupUri, 1650162548);
            bridge = await ChampionNFTBridge.new();
            await bridge.__initialize(nft.address, 1000, 1100);
            await nft.setBridge(bridge.address);
        });

        it("check for init", async () => {
            assert.equal(await nft.name(), "Champion-nft");
            assert.equal(await nft.symbol(), "CNFT");
        });

        it("check for tokenURI", async () => {
            await truffleAssert.reverts(nft.tokenURI(10000), "ERC721Metadata: URI query for nonexistent token");
            await nft.mintAdmin(owner)
            var url = await nft.tokenURI(10000);
            assert.equal(url, _initNotRevealedUri);

            await nft.setRevealed(true);
            var url = await nft.tokenURI(10000);
            assert.equal(url, _initBaseURI + "10000");

            await truffleAssert.reverts(nft.setDelivered(10000, true, {from:accounts[1]}), "caller neither owner nor bridge");
            await nft.setDelivered(10000, true);
            var url = await nft.tokenURI(10000);
            assert.equal(url, _pickupUri + "10000"); 
        });

        it("check for mintWhitelist", async () => {
            await nft.setWhitelistMerkleRoot(merkleTree.getHexRoot());
            await nft.setWhitelistAddressCustomLimitBatch(whitelistAddresses, [1,1,1]);

            let merkleProof_0 = merkleTree.getHexProof("0x" + keccak256(accounts[0]).toString('hex'));
            let merkleProof_1 = merkleTree.getHexProof("0x" + keccak256(accounts[1]).toString('hex'));
            let merkleProof_2 = merkleTree.getHexProof("0x" + keccak256(accounts[2]).toString('hex'));

            await truffleAssert.reverts(nft.mintWhitelist(1, merkleProof_0, {from:accounts[3]}), "Whitelist sale not started");
            await nft.setWhitelistSale(true)
            await truffleAssert.reverts(nft.mintWhitelist(1, merkleProof_0, {from:accounts[3]}), "Address not whitelisted");
            await truffleAssert.reverts(nft.mintWhitelist(1, merkleProof_1, {from:accounts[0]}), "Address not whitelisted");


            await truffleAssert.reverts(nft.mintWhitelist(100, merkleProof_0, {from:accounts[0]}), "Surpasses supply 30%");
            await nft.setReleaseSupplyTime(0);
            await truffleAssert.reverts(nft.mintWhitelist(100, merkleProof_0, {from:accounts[0]}), "Surpasses supply");
            await truffleAssert.reverts(nft.mintWhitelist(2, merkleProof_0, {from:accounts[0]}), "Minting above allocation");

            await nft.mintWhitelist(1, merkleProof_0, {from:accounts[0]});
            await nft.mintWhitelist(1, merkleProof_1, {from:accounts[1]});
            await nft.mintWhitelist(1, merkleProof_2, {from:accounts[2]});

            await truffleAssert.reverts(nft.mintWhitelist(1, merkleProof_0, {from:accounts[0]}), "Minting above allocation");

            let tokenIds = await nft.walletOfOwner(owner);
            assert.equal(tokenIds.length, 1);
            assert.equal(tokenIds[0], 10000);
        });

        it("check for mintAirdrop", async () => {
            await truffleAssert.reverts(nft.mintReserve(10), "the tokenId does not belong to you");
            await nft.setReserve(10, owner);
            await nft.mintReserve(10);
            await truffleAssert.reverts(nft.mintReserve(10), "ERC721: token already minted");
            let tokenIds = await nft.walletOfOwner(owner);
            assert.equal(tokenIds.length, 1);
            assert.equal(tokenIds[0], 10);
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
            nft = await ChampionNFT.new("Champion-nft", "CNFT", _initBaseURI, _initNotRevealedUri, _pickupUri, 1650162548);
            bridge = await ChampionNFTBridge.new();
            await bridge.__initialize(nft.address, 1000, 1100);
            await nft.setBridge(bridge.address);
            await nft.setWhitelistMerkleRoot(merkleTree.getHexRoot());
            await nft.setWhitelistAddressCustomLimitBatch(whitelistAddresses, [1,1,1]);
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

        it("check for setFristBuy", async () => {
            assert.equal(await bridge.fristBuyMap(10000), address_0);
            await truffleAssert.reverts(bridge.setFristBuy(10000, owner), "ERC721: owner query for nonexistent token");
            await nft.mintAdmin(owner)
            await truffleAssert.reverts(bridge.setFristBuy(10000, validator), "the tokenId does not belong to account");
            assert.equal(await bridge.fristBuyMap(10000), owner);
        });


        it("check for delivery validator 1", async () => {
            await bridge.addValidator(validator);
            await bridge.setRequiredSignatures(1);
            var signature = await sign(validator, sender, 10000, 900, testHash, bridge.address);
            
            await truffleAssert.reverts(bridge.delivery(sender, 10000, 900, testHash, signature.substring(2)), "caller is not a validator");
            await truffleAssert.reverts(bridge.delivery(sender, 10000, 900, testHash, signature.substring(2), {from: validator}), "ERC721: owner query for nonexistent token");
            await nft.mintAdmin(sender);
            await nft.setDelivered(10000, true)
            await truffleAssert.reverts(bridge.delivery(owner, 10000, 900, testHash, signature.substring(2), {from: validator}), "the tokenId does not belong to sender");
            await truffleAssert.reverts(bridge.delivery(sender, 10000, 900, testHash, signature.substring(2), {from: validator}), "the tokenId has been delivered");
            await nft.setDelivered(10000, false)
            await truffleAssert.reverts(bridge.delivery(sender, 10000, 0, testHash, signature.substring(2), {from: validator}), "signature verify failed");
            await truffleAssert.reverts(bridge.delivery(sender, 10000, 900, testHash, signature.substring(2), {from: validator}), "not enough medals to delivery - lv1");
            
            var signature = await sign(validator, sender, 10000, 1000, testHash, bridge.address);
            await bridge.delivery(sender, 10000, 1000, testHash, signature.substring(2), {from: validator})

            let isdelivered = await nft.isDelivered(10000);
            assert.equal(isdelivered, true);
        });

        it("check for delivery validator 2", async () => {
            let validator2 = accounts[2];
            await bridge.addValidator(validator);
            await bridge.addValidator(validator2);
            await bridge.setRequiredSignatures(2);
            await nft.mintAdmin(sender);

            var signature = await sign(validator, sender, 10000, 1000, testHash, bridge.address);
            await bridge.delivery(sender, 10000, 1000, testHash, signature.substring(2), {from: validator})

            var isdelivered = await nft.isDelivered(10000);
            assert.equal(isdelivered, false);

            var signature2 = await sign(validator2, sender, 10000, 1000, testHash, bridge.address);
            await bridge.delivery(sender, 10000, 1000, testHash, signature2.substring(2), {from: validator2})
            var isdelivered = await nft.isDelivered(10000);
            assert.equal(isdelivered, true);
        });

        it("check for delivery validator 1 not fristbuy", async () => {
            await bridge.addValidator(validator);
            await bridge.setRequiredSignatures(1);
            await nft.mintAdmin(sender);
            await nft.transferFrom(sender, owner, 10000, {from: sender});

            var signature = await sign(validator, owner, 10000, 1000, testHash, bridge.address);
            await truffleAssert.reverts(bridge.delivery(owner, 10000, 1000, testHash, signature.substring(2), {from: validator}), "not enough medals to delivery - lv2");

            var signature = await sign(validator, owner, 10000, 1100, testHash, bridge.address);
            await bridge.delivery(owner, 10000, 1100, testHash, signature.substring(2), {from: validator})

            var isdelivered = await nft.isDelivered(10000);
            assert.equal(isdelivered, true);
        });
    });
});