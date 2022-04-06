const Token = artifacts.require("Token");
const Donor = artifacts.require("Donor");
const Recipient = artifacts.require("Recipient");
const DonationMarket = artifacts.require("DonationMarket");
const RecipientStorage = artifacts.require("RecipientStorage");
const DonorStorage = artifacts.require("DonorStorage");
const DonationMarketStorage = artifacts.require("DonationMarketStorage");

module.exports = (deployer, network, accounts) => {
    //follow the sequence!!
    deployer.deploy(Token, {from: accounts[6]}).then(function() {
        return deployer.deploy(DonationMarketStorage, {from: accounts[6]}).then(function() {
            return deployer.deploy(DonationMarket, Token.address, DonationMarketStorage.address, {from:accounts[6]}).then(function() {
                return deployer.deploy(RecipientStorage,{from:accounts[6]}).then(function() {
                    return deployer.deploy(Recipient,Token.address,DonationMarket.address,RecipientStorage.address,{from:accounts[6]}) .then(function() {
                        return deployer.deploy(DonorStorage, {from:accounts[6]}).then(function() {
                            return deployer.deploy(Donor, Token.address, DonationMarket.address,Recipient.address, DonorStorage.address, {from:accounts[6]});
                        })
                    }) 
                })  
            })
        })  
    }) 
};

