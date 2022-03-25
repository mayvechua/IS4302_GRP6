// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;
import './Token.sol';
import './Recipient.sol';
contract Donor {

    enum donorState {created, donated} // what is the purpose?

    struct donor {
        donorState state;
        address owner;
        string username;
        string pw;
        uint256 walletValue; // amt of ether in wallet
    }


    Token tokenContract;
    Recipient recipientContract;

    constructor (Token tokenAddress, Recipient recipientAddress) public {
        tokenContract = tokenAddress;
        recipientContract = recipientAddress;
    }
    uint256 public numDonors = 0;
    mapping(uint256 => donor) public donors;
    mapping(uint256 => uint256[]) public tokensCreated; // donorId => list of tokenID that donor owns
    // mapping(uint256 => tokenState[]) public tokensCompleted; // store in database as historical
    // mapping(uint256 => tokenState[]) public tokensIncomplete;


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
        return newDonorId;  
    }

    //modifier to ensure a function is callable only by its donor  
    modifier ownerOnly(uint256 donorId) {
        require(donors[donorId].owner == msg.sender);
        _;
    }
    
    modifier validDonorId(uint256 donorId) {
        require(donorId < numDonors);
        _;
    }

    function createToken(uint256 donorId, uint256 amt, uint8 category) validDonorId(donorId) public payable {
        require(getWallet(donorId) >= amt, "Donor does not have enough ether to create token!");
        require(getWallet(donorId) < 100, "Donated amount hit limit!");
        donors[donorId].walletValue -= amt; 

        address payable token = payable(tokenContract.getOwner());
        //TODO: add mutex
        token.transfer(amt); 

        uint256 tokenID = tokenContract.createToken(donorId, amt, category);
        tokensCreated[donorId].push(tokenID);
    }
    //ToDO:  emergency stop in approve
    function approveRecipient(uint256 tokenId, uint256 recipientID, uint256 donorId) validDonorId(donorId) public {
        uint256 tokenIsUnlisted = tokenContract.approve(recipientID, tokenId, donors[donorId].owner);
        recipientContract.completeToken(recipientID, tokenId);
        if (tokenIsUnlisted == 2) {   
            bool isIndex = false;
            //store the token in database
            for (uint8 i; i< tokensCreated[donorId].length; i++) {
                if (tokensCreated[donorId][i] == tokenId) {
                    isIndex = true;
                }
                if (isIndex) {
                    tokensCreated[donorId][i] = tokensCreated[donorId][i+1];
                }
            }

             tokensCreated[donorId].pop();
        }
        //TODO: store completed tokens in historical database? do we need to as transaction are all recorded in block?
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

    function getActiveTokens(uint256 donorId) public view returns (uint256[] memory) {
        return tokensCreated[donorId]; // tokens active now, if want see historical tokens --> view in database 
    }


     //TODO: add selfdestruct function 
}