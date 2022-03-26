pragma solidity ^0.5.0;

import "./DataStorage.sol";

contract Database {
    DataStorage dataStorage;
    address developer = msg.sender;

    constructor(DataStorage dataStorageAddress) public {
        require(
            dataStorageAddress.getOwner() == developer,
            "Data storage not owned by developer"
        );
        dataStorage = dataStorageAddress;
    }

    modifier developerOnly() {
        require(msg.sender == developer);
        _;
    }

    function registerAccount(
        string memory username,
        string memory emailAddress,
        string memory password,
        string memory homeAddress,
        uint32 phoneNumber,
        uint256 userId
    ) public {
        require(
            dataStorage.getAccountAddress(username) == address(0),
            "Username taken"
        );
        dataStorage.setCredentials(
            username,
            emailAddress,
            password,
            homeAddress,
            msg.sender,
            phoneNumber,
            userId
        );
    }

    function destroy() public developerOnly {
        selfdestruct(msg.sender);
    }
}
