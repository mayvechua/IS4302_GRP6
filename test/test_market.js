const _deploy_contracts = require ("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
var assert = require("assert");

var DonationMarket = artifacts.require("../contracts/DonationMarket.sol");
var Recipient = artifacts.require("../contracts/Recipient.sol");
var Donor = artifacts.require("../contracts/Donor.sol");
var Token = artifacts.require("../contracts/Token.sol");

contract('Market', function(accounts) {
    let marketInstance ;
    let recipientInstance;
    let donorInstance;
    let tokenInstance;

    before(async () => {
        marketInstance = await DonationMarket.deployed();
        recipientInstance = await Recipient.deployed();
        donorInstance = await Donor.deployed();
        tokenInstance = await Token.deployed();
    });
    console.log("Testing Market Contract");

    //test create Listing
    it ("Create Listing", async() => {
        let donorD1 = await donorInstance.createDonor("name", {from: accounts[1]});
        let makeL1 = await marketInstance.createListing(0,50,"children", {from: accounts[1]});
        
        assert.notStrictEqual(
            makeL1,
            undefined,
            "Failed to make Listing"
        );
    });
    //test that donor cannot add request to their own listing
    it ("Test that donor cannot add request to their own listing", async() => {
        try {
            await marketInstance.addRequest(0,0,25,5,0,{from: accounts[1]});
        } catch (error) {
            const errorMsgReceived =  error.message.search("You cannot request for your own listing, try unlisting instead!") >= 0;
            assert(errorMsgReceived, "Error Message Received");
            return;
        };
        assert.fail("Expected Error not received!");
    });
    
    //test add request 
    it ("Add Request to listing", async() => {
        let createListingT1 = await marketInstance.createListing(0, 200, "children", {from: accounts[1]});
        let recipientR1 = await recipientInstance.createRecipient("name", {from: accounts[2]});
        let requestR1 = await recipientInstance.createRequest(0,25,5,"children", {from: accounts[6]});
        let addRequestT1 = await marketInstance.addRequest(0,0,25,5,1,{from: accounts[2]});
        
        truffleAssert.eventEmitted(addRequestT1, 'requestAdded');
    });

    //test that non-donor of listing cannot approve request
    it ("test that non-donor of listing cannot approve request", async() => {
         try {
            await marketInstance.approve(0,0,{from: accounts[2]});
        } catch (error) {
            const errorMsgReceived =  error.message.search("You are not the donor of this listing!") >= 0;
            assert(errorMsgReceived, "Error Message Received");
            return;
        };
        assert.fail("Expected Error not received!");    
    });
        

    //test that donor of listing is able to approve request
    it ("Approve Request", async() => {
        let getTokens = await tokenInstance.getCredit({from: accounts[1], value: 10000000000000000000});
        let approveRequestT1 = await marketInstance.approve(1,0,{from: accounts[1]});
        
        truffleAssert.eventEmitted(approveRequestT1, 'transferred');
    });

    //test unlist
    it ("unlist Listing", async() => {
        let unlistT1 = await marketInstance.unlist(0,{from: accounts[1]});
        truffleAssert.eventEmitted(unlistT1, 'listingUnlisted');
    });

    //test security functions that only owner of contract can excute 
        it ("test security functions that only owner can excute", async() => {
            await truffleAssert.passes(
                marketInstance.toggleContactStopped({from: accounts[6]}),
                'Emergency Stop Method should only be run by owner of contract!'
            );

            await truffleAssert.passes(
                marketInstance.selfDestruct({from: accounts[6]}),
                'Self Destruct should only be run by owner of contract!'
            );
 
        });
    



});

