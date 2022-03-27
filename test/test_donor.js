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

    it ("Top-Up Wallet Successful", async() => {
        let topUpD1 = await donorInstance.topUpWallet(0, {from: accounts[1], value: '1000000000000000000'}); // 1 ether
        let walletD1 = await donorInstance.getWallet(0, {from:accounts[1]});

        assert.notStrictEqual(
            walletD1,
            '1000000000000000000',
            "Top-Up value is not 1 ether"
        )

        truffleAssert.eventEmitted(topUpD1, 'toppedUpWallet');
        
    });

    it ("Create token by donor", async() => {
        let tokenD1 = await donorInstance.createToken(0, 100000, "food", {from: accounts[1]});

        assert.notStrictEqual(
            tokenD1,
            undefined,
            "Failed to create Token"
        );

        truffleAssert.eventEmitted(tokenD1, 'createdToken');
    });

    it ("Test top-up wallet limit works ", async() => {
        try {
            let topUpD2 = await donorInstance.topUpWallet(0, {from: accounts[1], value: '11000000000000000000'}); // 11 ether
            
        } catch (error) {
            const errorMsgReceived =  error.message.search("The top-up value is more than the wallet limit!") >= 0;
            assert(errorMsgReceived, "Error Message Received");
            return;
        }
    })

    it ("Approved Request by Recipient for Token", async() => {
        let recipientR1 = await recipientInstance.createRecipient("recipient", "password123", "food", {from: accounts[2]});
        let requestR1 = await recipientInstance.requestDonation(0, 1, 1000, {from: accounts[2]});

        let approvedD1 = await donorInstance.approveRecipient(1, 0, 0, {from: accounts[1]});

        truffleAssert.eventEmitted(approvedD1, 'approvedRecipient');
    })
 
    it ("test functions that only the donor can execute himself", async() => {
        
        await truffleAssert.passes(
            donorInstance.topUpWallet(0, {from: accounts[1], value: '1000000000000000000'}),
            "Only the donor can top up the wallet!"
        );

        await truffleAssert.passes(
            donorInstance.approveRecipient(1, 0, 0, {from: accounts[1]}),
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