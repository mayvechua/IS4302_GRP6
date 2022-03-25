// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

contract Token {
    uint256 supplyLimit; 
    uint256 createdCount;
    uint256 returnedCount;
    //add recipient and donor contract ?
    address owner;
    mapping(uint256 => token) public Tokens;
    mapping (bytes32 => state) public Tokenrequests; // hash(recipientid and tokenid) map state of request, asumming that recipient can only request for 1 token at a time 
    
    constructor() {
        owner = msg.sender;
        supplyLimit= 1000;
        //add recipient and donor contract ?
    }

    struct token {
        uint256 donorID;
        uint8 category;
        uint256 amt;
        uint256[] recipientIdList;

    }

    struct state {
        uint256 requestAmt;
        bool isCompleted;
        uint256 deadline;
        address recipientAddress;
    }

    //unlisting from donation market once amt < 1, remove from donor tokens also 
    function unlist(uint256 tokenID) public {
        returnedCount += 1;

        //TODO: unlist from Donation Market
        //TODO: store the token in database as historical - is this needed ?
        delete Tokens[tokenID];
    }

    //approve function - send eth to recipients
    //ToDO:  emergency stop in approve
    function approve(uint256 recipientID, uint256 tokenID, address donorAddress) public returns (uint256){
        //approve recipient and transfer ether
        state memory RequestInfo =  getState(tokenID, recipientID);
        RequestInfo.isCompleted = true;
        //TODO: add mutex
        address payable recipientTransferTo = payable( RequestInfo.recipientAddress);
        recipientTransferTo.transfer(RequestInfo.requestAmt);
        
        Tokens[tokenID].amt -= RequestInfo.requestAmt;
        if (Tokens[tokenID].amt  < 1) { //TODO: decide the number again
            unlist(tokenID);
            payable(donorAddress).transfer(Tokens[tokenID].amt);
            return Tokens[tokenID].amt;
        }
        return 2; //since we only unlist if less than 1 eth left


    }

    //getter function for the amt of each token
     function getTokenAmt(uint256 tokenID) public view  returns (uint256) {
        return Tokens[tokenID].amt;
    }

    

    //getter function for list of request each token 
    function getRequestRecipient(uint256 tokenID) public view  returns (uint256[] memory) {
        return Tokens[tokenID].recipientIdList;
    }

    //getter function of status for the each request of each token
    function  getState(uint256 tokenID, uint256 recipientID) public view returns (state memory) {
        bytes32 hashing = keccak256(abi.encode(recipientID, tokenID,  Tokens[tokenID].amt, Tokens[tokenID].category, Tokens[tokenID].donorID));
        return  Tokenrequests[hashing];
    }

    //getter function for token category for matching algorithm 
    function getCategory(uint256 tokenId) public view returns (uint8) {
        return Tokens[tokenId].category;
    }

    
    //add request to token  
    function addRequest(uint256 tokenID, uint256 recipientID, uint256 amt , uint256 deadline, address recipient) public {
        state memory newState = state( amt, false, deadline, recipient);
        bytes32 hashing = keccak256(abi.encode(recipientID, tokenID, Tokens[tokenID].amt, Tokens[tokenID].category, Tokens[tokenID].donorID));
        Tokenrequests[hashing] = newState;
        Tokens[tokenID].recipientIdList.push(recipientID);
    }

    // create token + list token on Donation market
    function createToken(uint256 donorID, uint256 amt, uint8 category) public payable returns (uint256) {
        require(createdCount - returnedCount <= supplyLimit, "Donation Capacity is reached!");
        //Creation of token 
        uint256[] memory recipientList;
        createdCount = createdCount +1;
        uint256 tokenID = createdCount;
        token memory newToken = token({
            donorID: donorID,
            amt: amt,
            category: category,
            recipientIdList:recipientList
        });
        Tokens[tokenID]= newToken;

        //TODO:listing of token on donation market 

        return tokenID;

    }
    //getter function for owner
    function getOwner() public view returns(address) {
        return owner;
    }
    //TODO: add selfdestruct function 
}