const _deploy_contracts = require ("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
var assert = require("assert");

var Token = artifacts.require("../contracts/Token.sol");
var Recipient = artifacts.require("../contracts/Recipient.sol")
var Donor = artifacts.require("../contracts/Donor.sol");

contract('Token', function(accounts) {
    let tokenInstance;
    let recipientInstance;
    let donorInstance;

    before(async () => {
        tokenInstance = await Token.deployed();
        recipientInstance = await Recipient.deployed();
        donorInstance = await Donor.deployed();
    });
    console.log("Testing Token Contract");

    it ("Test supply limit works ", async() => {
        try {
            let topUpD1 = await tokenInstance.getCredit({from: accounts[1], value: "110000000000000000000"}); // 11000 DT
            
        } catch (error) {
            const errorMsgReceived =  error.message.search("The top-up value is more than the supply limit!") >= 0;
            assert(errorMsgReceived, "Error Message Received");
            return;
        }
    })

    it ("Test transfer of DT", async() => {
        let donorD1 = await donorInstance.createDonor("donor", "password", {from: accounts[1]});
        let topUpD1 = await tokenInstance.getCredit({from: accounts[1], value: "1000000000000000000"});
        let recipientR1 = await recipientInstance.createRecipient("recipient", "password123", {from: accounts[2]});
        
        await truffleAssert.passes(tokenInstance.transferToken(accounts[1], accounts[2], 10, {from: accounts[1]}));
    })

    it ("Test setting new conversion rate", async() => {
        let setConversion = await tokenInstance.setConversionRate(1000, {from: accounts[6]});
        let getConversion = await tokenInstance.getConversionRate({from: accounts[6]});
        assert.equal(getConversion, 1000, "Conversion rate not set properly");
    })

    it ("Test functions with access restriction", async() => {
        try {
            let setConversion2 = await tokenInstance.setConversionRate(10000, {from: accounts[5]});
            
        } catch (error) {
            const errorMsgReceived =  error.message.search("you are not allowed to use this function") >= 0;
            assert(errorMsgReceived, "Error Message Received");
        }

        try {
            let destroyContract = await tokenInstance.destroyContract({from: accounts[5]});
            
        } catch (error) {
            const errorMsgReceived2 =  error.message.search("you are not allowed to use this function") >= 0;
            assert(errorMsgReceived2, "Error Message Received");
            return;
        }
    })

    it("Test cashing out", async() => {
        let topUpD1 = await tokenInstance.getCredit({from: accounts[1], value: "1000000000000000000"});
        await truffleAssert.passes(tokenInstance.cashOut(100, {from: accounts[1]}));
    })

});