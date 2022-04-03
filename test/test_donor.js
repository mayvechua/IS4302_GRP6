const _deploy_contracts = require ("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
var assert = require("assert");

var Token = artifacts.require("../contracts/Token.sol");
var Recipient = artifacts.require("../contracts/Recipient.sol")
var Donor = artifacts.require("../contracts/Donor.sol");
var DonorStorage = artifacts.require("../contracts/DonorStorage.sol");
var RecipientStorage = artifacts.require("../contracts/RecipientStorage.sol");
var DonationMarket = artifacts.require("../contracts/DonationMarket.sol");

contract('Donor', function(accounts) {
    let tokenInstance;
    let recipientInstance;
    let donorInstance;
    let donorStorageInstance;
    let recipientStorageInstance;
    let donationMarketInstance;

    before(async () => {
        tokenInstance = await Token.deployed();
        recipientInstance = await Recipient.deployed();
        donorInstance = await Donor.deployed();
        donorStorageInstance = await DonorStorage.deployed();
        recipientStorageInstance = await RecipientStorage.deployed();
        donationMarketInstance = await DonationMarket.deployed();
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

    it ("Create listing by donor", async() => {
        let topUpD1 = await tokenInstance.getCredit({from: accounts[1], value: "1000000000000000000"});
        let tokenD1 = await donorInstance.createListing(0, 10, "food", {from: accounts[1]});

        assert.notStrictEqual(
            tokenD1,
            undefined,
            "Failed to create Token"
        );

        truffleAssert.eventEmitted(tokenD1, 'createdToken');
    });

    it ("Approved Request by Recipient for Token", async() => {
        let recipientR1 = await recipientInstance.createRecipient("recipient", "password123", {from: accounts[2]});
        let requestR1 = await recipientInstance.createRequest(0, 1, 1000, "food", {from: accounts[2]});
        let requestedR1 = await recipientInstance.requestDonation(0, 0, 0, {from: accounts[2]});

        let approvedD1 = await donorInstance.approveRecipientRequest(0, 0, 0, 0, {from: accounts[1]});

        truffleAssert.eventEmitted(approvedD1, 'approvedRecipientRequest');
    })
 
    it ("test functions that only the donor can execute himself", async() => {
        await truffleAssert.passes(
            donorInstance.approveRecipientRequest(0, 0, 0, 0, {from: accounts[1]}),
            "Only the donor can approve the request!"
        );
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