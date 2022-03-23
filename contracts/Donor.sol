// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

contract Donor {

    enum donorState {created, donated}

    struct donor {
        donorState state;
        address owner;
        string username;
        string pw;
        uint256 walletValue; // amt of ether in wallet
    }
    struct tokenState {
        uint256 tokenId;
        uint256 completed; // 1: completed, 0: incomplete
        uint256 donated; // amt donated after the token is completed
    }

    uint256 public numDonors = 0;
    mapping(uint256 => donor) public donors;
    mapping(uint256 => tokenState[]) public tokensCreated; // donorId => tokenState
    mapping(uint256 => tokenState[]) public tokensCompleted;
    mapping(uint256 => tokenState[]) public tokensIncomplete;


    //function to create a new donor, and add to 'donors' map
    function createDonor (
        string memory name,
        string memory password
    ) public returns(uint256) {
        
        donor memory newDonor = donor(
            donorState.created,
            msg.sender, // donor address
            name,
            password,
            0
        );
        
        uint256 newDonorId = numDonors++;
        donors[newDonorId] = newDonor; //commit to state variable
        return newDonorId;   //return new diceId
    }

    //modifier to ensure a function is callable only by its owner    
    modifier ownerOnly(uint256 donorId) {
        require(donors[donorId].owner == msg.sender);
        _;
    }
    
    modifier validDonorId(uint256 donorId) {
        require(donorId < numDonors);
        _;
    }

    function createToken(uint256 tokenId, uint256 donorId, uint256 amt, address tokenAddress) validDonorId(donorId) public payable {
        require(getWallet(donorId) >= amt, "Donor does not have enough ether to create token!");

        tokenState memory newToken = tokenState(
            tokenId,
            0, // incomplete token ie. new donation
            amt // amount donor wants to donate
        );

        donors[donorId].walletValue -= amt; // 

        tokensCreated[donorId].push(newToken);
        tokensIncomplete[donorId].push(newToken);

        address payable recipient = payable(tokenAddress);

        recipient.transfer(amt); // transfer the ether to the token contract address -- is the sender the 
    }

    function completedToken(uint256 tokenId, uint256 donorId, uint256 amt) validDonorId(donorId) public payable {
        uint256 len = tokensCreated[donorId].length;
        for (uint i = 0; i< len; i++) {
            if (tokensCreated[donorId][i].tokenId == tokenId) {
                tokensCreated[donorId][i].completed = 1;
                tokensCreated[donorId][i].donated -= amt; // subtract the remainder balance that is not donated
                
                tokensCompleted[donorId].push(tokensCreated[donorId][i]); // add to tokensCompleted
                
                for (uint z = 0; z < tokensIncomplete[donorId].length; z++) { // remove from tokensIncomplete
                    if (tokensIncomplete[donorId][z].tokenId == tokenId) {
                        delete tokensIncomplete[donorId][z];
                    }
                }
                break;
            }
        }

        address payable _owner = payable(donors[donorId].owner);
        _owner.transfer(amt); // transfer back the remaining ether that is not donated to the donor
    }

    function topUpWallet(uint256 donorId) ownerOnly(donorId) validDonorId(donorId) public payable {
        donors[donorId].walletValue += msg.value;
    }

    function getWallet(uint256 donorId) ownerOnly(donorId) validDonorId(donorId) public view returns(uint256) {
        return donors[donorId].walletValue;
    } 

    function getDonorAddress(uint256 donorId) public view returns (address) { // ownerOnly?
        return donors[donorId].owner;
    }

    function getDonorHistory(uint256 donorId) public view returns (tokenState[] memory) {
        return tokensCreated[donorId]; // tokens incomplete and complete
    }

    function getDonorTokenCompleted(uint256 donorId ) public view returns (tokenState[] memory) {
        return tokensCompleted[donorId];
    }

    function getDonorTokenIncomplete(uint256 donorId ) public view returns (tokenState[] memory) {
        return tokensIncomplete[donorId];
    }
}