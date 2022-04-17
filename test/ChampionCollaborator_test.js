const { expect, assert } = require('chai');
const truffleAssert = require('truffle-assertions');
const { ethers } = require('ethers');
const Web3 = require('web3');
// Load compiled artifacts
const ChampionCollaborator = artifacts.require("ChampionCollaborator");
const web3 = new Web3(new Web3.providers.HttpProvider('HTTP://127.0.0.1:7545'));
// Start test block
contract('ChampionCollaborator Test', function (accounts) {
    
    describe('check for ChampionCollaborator',() => {
        let collaborator = null;
        const owner = accounts[0];
        const address_0 = "0x0000000000000000000000000000000000000000";
        
        beforeEach(async function () {
            collaborator = await ChampionCollaborator.new();
            await collaborator.__initialize();
        });

        it("check for addCollaborator", async () => {
            assert.equal((await collaborator.totalPercentage()).toNumber(), 0);

            await truffleAssert.reverts(collaborator.addCollaborator(address_0, 1000), "Collaborator cannot be an empty address");
            await truffleAssert.reverts(collaborator.addCollaborator(owner, 10001), "totalPercentage will be greater than 10000");

            await collaborator.addCollaborator(owner, 4000);
            assert.equal((await collaborator.totalPercentage()).toNumber(), 4000);

            await truffleAssert.reverts(collaborator.addCollaborator(owner, 6001), "Collaborator already exists");
            await truffleAssert.reverts(collaborator.addCollaborator(accounts[1], 6001), "totalPercentage will be greater than 10000");

            await collaborator.addCollaborator(accounts[1], 6000);
            assert.equal((await collaborator.totalPercentage()).toNumber(), 10000);

            let info1 = await collaborator.getCollaborator(owner);
            let info2 = await collaborator.getCollaborator(accounts[1]);
            assert.equal(info1.percentage, 4000);
            assert.equal(info1.active, true);

            assert.equal(info2.percentage, 6000);
            assert.equal(info2.active, true);
        });

        it("check for setCollaborator", async () => {
            await collaborator.addCollaborator(owner, 4000);
            await collaborator.addCollaborator(accounts[1], 6000);
            assert.equal((await collaborator.totalPercentage()).toNumber(), 10000);

            await truffleAssert.reverts(collaborator.setCollaborator(address_0, 1000), "Collaborator cannot be an empty address");
            await truffleAssert.reverts(collaborator.setCollaborator(accounts[2], 10001), "Collaborator is not exists");
            await truffleAssert.reverts(collaborator.setCollaborator(accounts[1], 6001), "totalPercentage will be greater than 10000");

            await collaborator.setCollaborator(accounts[1], 5000);
            assert.equal((await collaborator.totalPercentage()).toNumber(), 9000);

            let info1 = await collaborator.getCollaborator(owner);
            let info2 = await collaborator.getCollaborator(accounts[1]);
            assert.equal(info1.percentage, 4000);
            assert.equal(info1.active, true);

            assert.equal(info2.percentage, 5000);
            assert.equal(info2.active, true);
        });

        it("check for delCollaborator", async () => {
            await collaborator.addCollaborator(owner, 4000);
            await collaborator.addCollaborator(accounts[1], 6000);
            assert.equal((await collaborator.totalPercentage()).toNumber(), 10000);

            await truffleAssert.reverts(collaborator.delCollaborator(address_0), "Collaborator cannot be an empty address");
            await truffleAssert.reverts(collaborator.delCollaborator(accounts[2]), "Collaborator is not exists");

            await collaborator.delCollaborator(accounts[1]);
            assert.equal((await collaborator.totalPercentage()).toNumber(), 4000);

            let info1 = await collaborator.getCollaborator(owner);
            let info2 = await collaborator.getCollaborator(accounts[1]);
            assert.equal(info1.percentage, 4000);
            assert.equal(info1.active, true);

            assert.equal(info2.percentage, 0);
            assert.equal(info2.active, false);
        });

        it("check for withdraw", async () => {
            await truffleAssert.reverts(collaborator.withdraw(), "no balance to withdraw");

            await collaborator.sendTransaction({from:owner,value:ethers.utils.parseEther("0.1")})
            assert.equal((await web3.eth.getBalance(collaborator.address)).toString(), "100000000000000000");

            await collaborator.withdraw();
            assert.equal((await web3.eth.getBalance(collaborator.address)).toString(), "100000000000000000");

            let balance1 = web3.utils.toBN((await web3.eth.getBalance(accounts[1])).toString())
            let balance2 = web3.utils.toBN((await web3.eth.getBalance(accounts[2])).toString())

            await collaborator.addCollaborator(accounts[1], 5000);
            await collaborator.withdraw();
            assert.equal((await web3.eth.getBalance(collaborator.address)).toString(), "50000000000000000");
            assert.equal((await web3.eth.getBalance(accounts[1])).toString(), (balance1.add(web3.utils.toBN("50000000000000000"))).toString());

            await collaborator.addCollaborator(accounts[2], 5000);
            await collaborator.withdraw();

            assert.equal((await web3.eth.getBalance(collaborator.address)).toString(), "0");
            assert.equal((await web3.eth.getBalance(accounts[1])).toString(), (balance1.add(web3.utils.toBN("75000000000000000"))).toString());
            assert.equal((await web3.eth.getBalance(accounts[2])).toString(), (balance2.add(web3.utils.toBN("25000000000000000"))).toString());
        });
    });
});