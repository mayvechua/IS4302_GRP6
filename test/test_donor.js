const _deploy_contracts = require ("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
var assert = require("assert");

var Token = artifacts.require("../contracts/Token.sol");
var Recipient = artifacts.require("../contracts/Recipient.sol")
var Donor = artifacts.require("../contracts/Donor.sol");

contract('Donor', function(accounts) {
    let tokenInstance;
    let recipientInstance;
    let donorInstance;

    before(async () => {
        tokenInstance = await Token.deployed();
        recipientInstance = await Recipient.deployed();
        donorInstance = await Donor.deployed();
    });
    console.log("Testing Donor Contract");

    //test create token
    it ("Creating Donor", async() => {
        let donorD1 = await donorInstance.createDonor("donor", "password", {from: accounts[1]});
        
        assert.notStrictEqual(
            donorD1,
            undefined,
            "Failed to create Donor"
        );
    });


    it ("Create Listing by donor", async() => {
        let getTokens = await tokenInstance.getCredit({from: accounts[1], value: 1000000000000000000})
        let Listing = await donorInstance.createListing(0,50, "children", {from: accounts[1]});
        assert.notStrictEqual(
            Listing,
            undefined,
            "Failed to create Listing"
        );

        truffleAssert.eventEmitted(Listing, 'createdListing');
    });

    it ("test functions that only the donor can execute himself", async() => {
        try {
            await donorInstance.approveRecipientRequest(0,0, 0, 0, {from: accounts[2]});
        } catch (error) {
            const errorMsgReceived =  error.message.search("You are not the donor!") >= 0;
            assert(errorMsgReceived, "Error Message Received");
            return;
        };
        assert.fail("Expected Error not received!");

    })


    it ("Approved Request by Recipient for Token", async() => {
        let recipientR1 = await recipientInstance.createRecipient("recipient", "password123", {from: accounts[2]});
        let requestR1 = await recipientInstance.createRequest(0, 50, 2,"children", {from: accounts[6]});
        let addrequest = await recipientInstance.requestDonation(0, 0, 0, {from: accounts[2]});
        let approvedD1 = await donorInstance.approveRecipientRequest(0,0, 0, 0, {from: accounts[1]});
        truffleAssert.eventEmitted(approvedD1, 'approvedRecipientRequest');
    })
 

    it ("test security functions that only owner can execute", async() => {
        await truffleAssert.passes(
            donorInstance.toggleContactStopped({from: accounts[6]}),
            'only the owner of the contract can call emergency stop!'
        );

        await truffleAssert.passes(
            donorInstance.destroyContract({from: accounts[6]}),
            'only the owner of the contract destroy the contract!'
        );

    });

    

});