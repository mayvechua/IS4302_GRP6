// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

contract DonationToken {
    uint256 supplyLimit; 
    uint256 createdCount;
    uint256 returnedCount;
    //add recipient and donor contract ?
    address owner;
    mapping (uint256 => token) public tokens; // token id map  donir
    mapping (uint8 => uint256[]) public donorTokens; // donor map token id
    mapping (uint8 => uint256[]) public recipientsRequest;  // recipeints map token id
    mapping (bytes32 => state) public Tokenrequests; // hash(recipientid and tokenid) map state of request, asumming that recipient can only request for 1 token at a time 
    mapping (uint256 => uint8[]) public tokenRecipients;
    constructor() {
        owner = msg.sender;
        supplyLimit= 1000;
        //add recipient and donor contract ?
    }

    struct token {
        uint8 donorID;
        uint8 category;
        uint256 amt;
    }

    struct state {
        uint256 requestAmt;
        bool isCompleted;
        uint256 deadline;
    }

    //unlisting from donation market once amt < 1, remove from donor tokens also 
    function unlist(uint256 tokenID) public {
        bool isIndex = false;
        //delete for donor 
        uint256 length = donorTokens[tokens[tokenID].donorID].length;
        for (uint i = 0; i< length; i++){
            if (donorTokens[tokens[tokenID].donorID][i] == tokenID) {
                isIndex = true;
            }
            if (isIndex) {
                donorTokens[tokens[tokenID].donorID][i] = donorTokens[tokens[tokenID].donorID][i+1];
            }
        }
        donorTokens[tokens[tokenID].donorID].pop();

        //delete for recipients -- TODO: optimize it
        for (uint i = 0; i< tokenRecipients[tokenID].length; i++){
            bytes32 hashing = keccak256(abi.encode(tokenRecipients[tokenID][i], tokenID, tokens[tokenID].amt, tokens[tokenID].category, tokens[tokenID].donorID));
            delete Tokenrequests[hashing];
            uint256 recipientLength = recipientsRequest[tokenRecipients[tokenID][i]].length;
            for (uint x = 0; x< recipientLength; x++){
                if (recipientsRequest[tokenRecipients[tokenID][i]][x] == tokenID) {
                    isIndex = true;
                }
                if (isIndex) {
                    recipientsRequest[tokenRecipients[tokenID][i]][x] = recipientsRequest[tokenRecipients[tokenID][i]][x+1];
                }
            }
            recipientsRequest[tokenRecipients[tokenID][i]].pop();
        }


        delete tokens[tokenID];
        delete tokenRecipients[tokenID];
        returnedCount += 1;

        //TODO: unlist from Donation Market
    }

    //approve function - send eth to recipients
    function approve(uint8 recipientID, uint256 tokenID) public {
         bytes32 hashing = keccak256(abi.encode(recipientID, tokenID, tokens[tokenID].amt, tokens[tokenID].category, tokens[tokenID].donorID));
        //get recipient address from recipient contract
        state memory requestState = Tokenrequests[hashing];
        // .transfer(requestState.requestAmt);
        requestState.isCompleted = true;
        tokens[tokenID].amt -= requestState.requestAmt;
        if (tokens[tokenID].amt  < 1) {
            unlist(tokenID);
        }


    }
    

    //getter function for list of request each token 
    function getRecipients(uint8 tokenID) public view  returns (uint8[] memory) {
        return tokenRecipients[tokenID];
    }
    //getter function tokens owned by donor
    function getTokensOwned(uint8 donorID) public view  returns (uint256[] memory) {
        return donorTokens[donorID];
    }

    //getter function request by recipient
    function getRequests(uint8 recipientID) public view  returns (uint256[] memory) {
        return recipientsRequest[recipientID];
    }

    
    
    //add request to token  
    function addRequest(uint256 tokenID, uint8 recipientID, uint256 requestAmt, uint256 deadline) public {
        token memory requestedToken = tokens[tokenID];


        require(requestedToken.donorID != 0); //valid token only - donor id starts from 1
        //TODO:check that it is a validated recipient 
        require(requestAmt > 0); // ensure that requestamt is not 0 --> clarify checking !

        
        state memory newState = state (requestAmt, false, deadline);
        bytes32 hashing = keccak256(abi.encode(recipientID, tokenID, requestedToken.amt, requestedToken.category, requestedToken.donorID));
        Tokenrequests[hashing] = newState;
        tokenRecipients[tokenID].push(recipientID);
        recipientsRequest[recipientID].push(tokenID);

    }
    // create token + list token on Donation market
    function create(uint8 donorID, uint256 amt, uint8 category) public payable returns (uint256) {
        require(createdCount - returnedCount <= supplyLimit);
        require(msg.value >= amt);
        //TODO: trasnfer from donor to this contract! 
        //Creation of token 
        createdCount = createdCount +1;
        uint256 tokenID = createdCount;
        token memory newToken = token({
            donorID: donorID,
            amt: amt,
            category: category
        });
        tokens[tokenID]= newToken;

        //mapping donor 
        donorTokens[donorID].push(tokenID);

        //TODO:listing of token on donation market 

        return tokenID;

    }
    // ownership, access restriction, emergency stop in approve, mutex in approve,Balance limit, mortal
}