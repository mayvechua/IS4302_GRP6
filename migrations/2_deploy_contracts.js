const Token = artifacts.require("Token");
const Donor = artifacts.require("Donor");
const Recipient = artifacts.require("Recipient");

module.exports = (deployer, network, accounts) => {
    //follow the sequence!!
    deployer.deploy(Token, {from: accounts[6]}).then(function() {
        return deployer.deploy(Recipient, Token.address, {from:accounts[6]}).then(function() {
            return deployer.deploy(Donor, Token.address, Recipient.address, {from:accounts[6]});
        })
    })
};

