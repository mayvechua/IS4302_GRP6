const Token = artifacts.require("Token");
const DonationMarket = artifacts.require("DonationMarket");
const Donor = artifacts.require("Donor");
const DonorStorage = artifacts.require("DonorStorage");
const Recipient = artifacts.require("Recipient");
const RecipientStorage = artifacts.require("RecipientStorage");

module.exports = (deployer, network, accounts) => {
    //follow the sequence!!
    deployer.deploy(Token, {from: accounts[6]}).then(function() {
        return deployer.deploy(RecipientStorage, {from:accounts[6]}).then(function() {
            return deployer.deploy(DonorStorage, {from:accounts[6]}).then(function() {
                return deployer.deploy(DonationMarket, Token.address, {from:accounts[6]}).then(function() {
                    return deployer.deploy(Recipient, Token.address, DonationMarket.address, RecipientStorage.address, {from:accounts[6]}).then(function() {
                        return deployer.deploy(Donor, Token.address, DonationMarket.address, Recipient.address, DonorStorage.address, {from:accounts[6]});
                    })
                })
            })
        })
    })
};

