// SPDX-License-Identifier: MIT
pragma solidity >=0.6.1;

contract DataStorage {
    struct Credentials {
        string username;
        string emailAddress;
        string password;
        string homeAddress;
        address accountAddress;
        uint32 phoneNumber;
        uint256 userId; 
    }

    address owner = msg.sender;
    mapping(string => Credentials) loginCredentialsStorage;
    mapping(string => uint256) exchangeRateStorage;

    modifier ownerOnly() {
        require(msg.sender == owner);
        _;
    }

    function destroy() public ownerOnly {
        address payable addr = payable(msg.sender);
        selfdestruct(addr);
    }

    //Getter methods
    function getOwner() public view returns (address) {
        return owner;
    }

    function getEmailAddress(string memory username) public view returns (string memory) {
        return loginCredentialsStorage[username].emailAddress;
    }

    function getPassword(string memory username) public view returns (string memory) {
        return loginCredentialsStorage[username].password;
    }

    function getHomeAddress(string memory username) public view returns (string memory) {
        return loginCredentialsStorage[username].homeAddress;
    }

    function getAccountAddress(string memory username) public view returns (address) {
        return loginCredentialsStorage[username].accountAddress;
    }

    function getPhoneNumber(string memory username) public view returns (uint32) {
        return loginCredentialsStorage[username].phoneNumber;
    }

    function getUserId(string memory username) public view returns (uint256) {
        return loginCredentialsStorage[username].userId;
    }

    function getExchangeRate(string memory countryCode) public view returns (uint256) {
        return exchangeRateStorage[countryCode];
    }

    //Setter methods
    function setCredentials(string memory username, string memory emailAddress, string memory password, 
        string memory homeAddress, address accountAddress, uint32 phoneNumber, uint256 userId) public {
            Credentials memory loginCredentials = Credentials(username, emailAddress, password, homeAddress, accountAddress, 
                phoneNumber, userId);
            loginCredentialsStorage[username] = loginCredentials;
    }

    function setExchangeRate(string memory countryCode, uint256 rate) public {
        exchangeRateStorage[countryCode] = rate;
    }
}