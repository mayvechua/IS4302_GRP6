const Token = artifacts.require("Token");

module.exports = (deployer, network, accounts) => {
    //follow the sequence!!
    deployer.deploy(Token)
};

