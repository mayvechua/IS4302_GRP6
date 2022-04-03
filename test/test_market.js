const _deploy_contracts = require ("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
var assert = require("assert");

var Market = artifacts.require("../contracts/DonationMarket.sol");

contract('Market', function(accounts) {
    let marketInstance ;
    before(async () => {
        marketInstance = await Market.deployed();
    });
    console.log("Testing Token Contract");

    //test create token
    it ("Add Listing", async() => {
        let makeT1 = await tokenInstance.createListing(0,50,"children", {from: accounts[1], value: 5000000000000000000});
        
        assert.notStrictEqual(
            makeT1,
            undefined,
            "Failed to make Token"
        );
    });
    //test that donor cannot add request to their own token 
    it ("Test that donor cannot add request to their own token  ", async() => {
        try {
            await tokenInstance.addRequest(1,1,1,10102022,{from: accounts[1]});
        } catch (error) {
            const errorMsgReceived =  error.message.search("You cannot request for your own token, try unlisting instead!") >= 0;
            assert(errorMsgReceived, "Error Message Received");
            return;
        };
    });
    
    //test add request 
    it ("Add Request to Token", async() => {
        let addRequestT1 = await tokenInstance.addRequest(1,1,1,10102022,{from: accounts[2]});
        
        truffleAssert.eventEmitted(addRequestT1, 'requestAdded');
    });

    //test that non-donor of token cannot approve request
        it ("test that non-donor of token cannot approve request", async() => {
            try {
                await tokenInstance.approve(1,1,{from: accounts[2]});
            } catch (error) {
                const errorMsgReceived =  error.message.search("You are not the donor of this token!") >= 0;
                assert(errorMsgReceived, "Error Message Received");
                return;
            };
    
        });
        

    //test approve
    it ("Approve Request", async() => {
        let approveRequestT1 = await tokenInstance.approve(1,1,{from: accounts[1]});
        
        truffleAssert.eventEmitted(approveRequestT1, 'transferred');
    });

    //test unlist
    it ("unlist Token", async() => {
        let unlistT1 = await tokenInstance.unlist(1,{from: accounts[1]});
        truffleAssert.eventEmitted(unlistT1, 'tokenUnlisted');
    });

    //test security functions that only owner can excute 
        it ("test security functions that only owner can excute", async() => {
            await truffleAssert.passes(
                tokenInstance.stopContract({from: accounts[6]}),
                'Emergency Stop Method should only be run by owner of contract!'
            );
 
            await truffleAssert.passes(
                tokenInstance.resumeContract({from: accounts[6]}),
                'Emergency Resume Method should only be run by owner of contract!'
            );

            await truffleAssert.passes(
                tokenInstance.setBalanceLimit(600,{from: accounts[6]}),
                'Set Balance Limit should only be run by owner of contract!'
            );
 
        });
    



});

