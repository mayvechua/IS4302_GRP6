const _deploy_contracts = require ("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
var assert = require("assert");

var Token = artifacts.require("../contracts/Token.sol");
var Donor = artifacts.require("../contracts/Donor.sol");
var Recipient = artifacts.require("../contracts/Recipient.sol");
var DonationMarket = artifacts.require("../contracts/DonationMarket.sol");

contract('Recipient', function(accounts) {
    let tokenInstance;
    let donorInstance;
    let recipientInstance;
    let marketInstance;

    before(async () => {
        tokenInstance = await Token.deployed();
        donorInstance = await Donor.deployed();
        recipientInstance = await Recipient.deployed();
        marketInstance = await DonationMarket.deployed();
    });
    console.log("Testing Recipient Contract");

    //test create token
    it ("Creating Recipient", async() => {
        let recipientR1 = await recipientInstance.createRecipient("recipient", {from: accounts[2]});
        
        assert.notStrictEqual(
            recipientR1,
            undefined,
            "Failed to create Recipient"
        );
    });

    it ("Create request successful", async() => {
        let requestR1 = await recipientInstance.createRequest(0, 10, 2, "food", {from: accounts[6]});
        
        truffleAssert.eventEmitted(requestR1, 'requestCreated');
    })

    it ("Request donation Successful", async() => {
        let donorD1 = await donorInstance.createDonor("donor", {from: accounts[1]});
        let listingM1 = await marketInstance.createListing(0, 50, "food", {from: accounts[1]});
        let requestedR1 = await recipientInstance.requestDonation(0, 0, 1, {from: accounts[2]});

        truffleAssert.eventEmitted(requestedR1, 'requestedDonation')
    });


    it ("Complete request function", async() => {
        let completedR1 = await recipientInstance.completeRequest(0, 0, accounts[1], {from: accounts[1]});
        
        truffleAssert.eventEmitted(completedR1, 'completedRequest');
        
    })

    it ("Cancel request function", async() => {
        let request = await recipientInstance.createRequest(0, 10, 2, "children", {from: accounts[6]});
        let listing = await marketInstance.createListing(0, 50, "children", {from: accounts[1]});
        let requested = await recipientInstance.requestDonation(0, 1, 2, {from: accounts[2]});
        let cancel = await recipientInstance.cancelRequest(0,2,1, {from: accounts[2]});

        truffleAssert.eventEmitted(cancel, "requestCancelled");
    })

    it ("test functions that only the recipient can execute himself", async() => {
        
        let recipientR2 = await recipientInstance.createRecipient("recipient", {from: accounts[4]});
        let requestR2 = await recipientInstance.createRequest(1, 10, 2, "food", {from: accounts[6]});
        let donorD2 = await donorInstance.createDonor("donor", {from: accounts[5]});
        let listingM2 = await marketInstance.createListing(1, 50, "food", {from: accounts[5]});
        let requestedR2 = await recipientInstance.requestDonation(1, 2, 3, {from: accounts[4]});

        try {
            await recipientInstance.withdrawTokens(1, {from: accounts[9]});
        } catch (error) {
            const errorMsgReceived =  error.message.search("you are not the recipient!") >= 0;
            assert(errorMsgReceived, "Error Message Received");
            return;
        };
        assert.fail("Expected Error not received!");

        let recipientR3 = await recipientInstance.createRecipient("recipient", {from: accounts[7]});
        let requestR3 = await recipientInstance.createRequest(2, 10, 2, "food", {from: accounts[6]});
        let donorD3 = await donorInstance.createDonor("donor", {from: accounts[8]});
        let listingM3 = await marketInstance.createListing(2, 50, "food", {from: accounts[8]});

        try {
            await recipientInstance.requestDonation(2, 3, 4, {from: accounts[9]});

        } catch (error) {
            const errorMsgReceived =  error.message.search("you are not the recipient!") >= 0;
            assert(errorMsgReceived, "Error Message Received");
            return;
        };
        assert.fail("Expected Error not received!");

        let requestR4 = await recipientInstance.createRequest(0, 10, 2, "elderly", {from: accounts[6]});
        let listingM4 = await marketInstance.createListing(0, 50, "elderly", {from: accounts[1]});
        let requestedR4 = await recipientInstance.requestDonation(0, 4, 5, {from: accounts[2]});

        try {
            await recipientInstance.cancelRequest(0,5,4, {from: accounts[9]});

        } catch (error) {
            const errorMsgReceived =  error.message.search("you are not the recipient!") >= 0;
            assert(errorMsgReceived, "Error Message Received");
            return;
        };
        assert.fail("Expected Error not received!");
    })

    it ("test security functions that only owner can execute", async() => {
        await truffleAssert.passes(
            recipientInstance.toggleContactStopped({from: accounts[6]}),
            'only the owner of the contract can call emergency stop!'
        );

        await truffleAssert.passes(
            recipientInstance.destroyContract({from: accounts[6]}),
            'only the owner of the contract destroy the contract!'
        );

    });

    

});