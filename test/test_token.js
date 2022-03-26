const _deploy_contracts = require ("../migrations/2_deploy_contracts");
const truffleAssert = require("truffle-assertions");
var assert = require("assert");

var Token = artifacts.require("../contracts/Token.sol");

contract('Token', function(accounts) {
    let tokenInstance ;
    before(async () => {
        tokenInstance = await Token.deployed();
    });
    console.log("Testing Token Contract");

    //test create token
    it ("Make Token", async() => {
        let makeT1 = await tokenInstance.createToken(1,5,"children", {from: accounts[1], value: 5000000000000000000});
        
        assert.notStrictEqual(
            makeT1,
            undefined,
            "Failed to make Token"
        );
    });


    //test add request 
    it ("Add Request to Token", async() => {
        let addRequestT1 = await tokenInstance.addRequest(1,1,1,10102022,{from: accounts[2]});
        
        truffleAssert.eventEmitted(addRequestT1, 'requestAdded');
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



});

