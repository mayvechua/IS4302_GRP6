const _deploy_contracts = require ("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
var assert = require("assert");

var Token = artifacts.require("../contracts/Token.sol");
var Recipient = artifacts.require("../contracts/Recipient.sol")

contract('Recipient', function(accounts) {
    let tokenInstance;
    let recipientInstance;

    before(async () => {
        tokenInstance = await Token.deployed();
        recipientInstance = await Recipient.deployed();
    });
    console.log("Testing Recipient Contract");

    //test create token
    it ("Creating Recipient", async() => {
        let recipientR1 = await recipientInstance.createRecipient("recipient", "password", "food", {from: accounts[2]});
        
        assert.notStrictEqual(
            recipientR1,
            undefined,
            "Failed to create Donor"
        );
    });


    it ("Request donation Successful", async() => {
        let tokenD1 = await tokenInstance.createToken(0, 100000, "food", {from: accounts[1]});

        let requestR1 = await recipientInstance.requestDonation(0, 1, 10, 7, {from: accounts[2]}) 
        
        truffleAssert.eventEmitted(requestR1, 'requestedDonation')
    });


    it ("Complete token function", async() => {
        let completedR1 = await recipientInstance.completeToken(0, 1, {from: accounts[1]});
        
        truffleAssert.eventEmitted(completedR1, 'completedToken');
        
    })

    it ("test functions that only the recipient can execute himself", async() => {
        
        await truffleAssert.passes(
            recipientInstance.withdrawTokens(0, {from: accounts[2]}),
            "Only the recipient can withdraw tokens!"
        );

        await truffleAssert.passes(
            recipientInstance.requestDonation(0, 1, 10, 7, {from: accounts[2]}),
            "Only the recipient can make a request!"
        );
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