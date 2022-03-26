// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

contract Token {
    uint256 supplyLimit; 
    uint256 createdCount;
    uint256 returnedCount;
    address owner;
    uint256 contractEthBalance;
    uint256 balanceLimit;
    mapping(uint256 => token) public Tokens;
    mapping (bytes32 => state) public Tokenrequests; // hash(recipientid and tokenid) map state of request, asumming that recipient can only request for 1 token at a time 
   
    struct token {
        uint256 donorID;
        address donorAddress;
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

    constructor() {
        owner = msg.sender;
        supplyLimit= 1000;
        balanceLimit = 10000;
        //add recipient and donor contract ?
    }


    //Access Restrictions
    modifier tokenDonorOnly(uint256 tokenID) {
        require(tx.origin == Tokens[tokenID].donorAddress, "You are not the donor of this token!");
        _;
    }


    modifier validTokenOnly(uint256 tokenID) {
        require(tokenID <createdCount, "Invalid Token!");
         _;
    }

    modifier ownerOnly() {
        require(msg.sender == owner, "You are not allowed to use this function!");
         _;
    }

    //Security Functions 

    bool internal locked;
    bool isStopped = false;

    modifier noReentrancy() {
        require(!locked, "No re-entrancy");
        _;
    }


    modifier stoppedInEmergency {
        require(!isStopped);
        _;
    }

    //Emergency Stop
    function stopContract() public ownerOnly() {
        isStopped = true;
    }

    function resumeContract() public  ownerOnly()  {
        isStopped = false;
    }

    //setter function for contract balance limit
    function setBalanceLimit(uint256 newLimit) public  ownerOnly() {
        balanceLimit = newLimit;
        
    }
    
    function selfDestruct() public ownerOnly() {
        address payable addr = payable(owner);
        selfdestruct(addr); 
    }

    //Events
    event transferred(uint256 tokenID, address recipient);
    event tokenUnlisting(uint256 tokenID);
    event requestAdded(uint256 tokenID, address recipient);
    event tokenCreated(uint256 tokenID);




    //Core Functions
    function unlist(uint256 tokenID, address donorAddress) public  noReentrancy() validTokenOnly(tokenID) tokenDonorOnly(tokenID) stoppedInEmergency {
        require(!locked, "No re-entrancy");
        returnedCount += 1;
        //TODO: unlist from Donation Market
        //TODO: store the token in database as historical - is this needed ?
        delete Tokens[tokenID];
        locked = true;
        require(contractEthBalance >= Tokens[tokenID].amt, "Insufficient balance in contract pool!");
        payable(donorAddress).transfer(Tokens[tokenID].amt);
        contractEthBalance -= Tokens[tokenID].amt;
        locked = false;
      
        
    }
    

    //approve function - send eth to recipients, minus amt from token 
    function approve(uint256 recipientID, uint256 tokenID, address donorAddress) public  noReentrancy() validTokenOnly(tokenID) tokenDonorOnly(tokenID) stoppedInEmergency returns (uint256){
        require(!locked, "No re-entrancy");
        state memory RequestInfo =  getState(tokenID, recipientID);
        RequestInfo.isCompleted = true;
        address payable recipientTransferTo = payable( RequestInfo.recipientAddress);
        locked = true;
        require(contractEthBalance >= RequestInfo.requestAmt, "Insufficient balance in contract pool!");
        recipientTransferTo.transfer(RequestInfo.requestAmt);
        contractEthBalance -= RequestInfo.requestAmt;
        locked = false;
        emit transferred(tokenID, recipientTransferTo);
        
        Tokens[tokenID].amt -= RequestInfo.requestAmt;
        if (Tokens[tokenID].amt  < 1) { //TODO: decide the number again
            emit tokenUnlisting(tokenID);
            unlist(tokenID, donorAddress);
            return Tokens[tokenID].amt;
          
        }
        return 2; //since we only unlist if less than 1 eth left


    }
    
    //add request to token  
    function addRequest(uint256 tokenID, uint256 recipientID, uint256 amt , uint256 deadline, address recipient) public  validTokenOnly(tokenID){
        state memory newState = state( amt, false, deadline, recipient);
        bytes32 hashing = keccak256(abi.encode(recipientID, tokenID, Tokens[tokenID].amt, Tokens[tokenID].category, Tokens[tokenID].donorID));
        Tokenrequests[hashing] = newState;
        Tokens[tokenID].recipientIdList.push(recipientID);
        emit requestAdded(tokenID, recipient);
    }

    // create token + list token on Donation market
    function createToken(uint256 donorID, uint256 amt, uint8 category) public payable returns (uint256) {
        require(createdCount - returnedCount <= supplyLimit, "Donation Market Capacity is reached!");
        require(contractEthBalance <= balanceLimit, "The limited amount of ETH stored in this contract is reached!");
        contractEthBalance += amt;
        uint256[] memory recipientList;
        createdCount+=1;
        uint256 tokenID = createdCount;
        token memory newToken = token(donorID,tx.origin, category, amt,recipientList);
        Tokens[tokenID]= newToken;
        emit tokenCreated(tokenID);

        //TODO:listing of token on donation market 

        return tokenID;

    }



    //Getter Functions
    //getter function for the amt of each token
     function getTokenAmt(uint256 tokenID) public view  validTokenOnly(tokenID) returns (uint256) {
        return Tokens[tokenID].amt;
    }

    //getter function for list of request each token 
    function getRequestRecipient(uint256 tokenID) public view tokenDonorOnly(tokenID) validTokenOnly(tokenID) returns (uint256[] memory) {
        return Tokens[tokenID].recipientIdList;
    }

    //getter function of status for the each request of each token
    function  getState(uint256 tokenID, uint256 recipientID) public view  validTokenOnly(tokenID)returns (state memory) {
        bytes32 hashing = keccak256(abi.encode(recipientID, tokenID,  Tokens[tokenID].amt, Tokens[tokenID].category, Tokens[tokenID].donorID));
        return  Tokenrequests[hashing];
    }

    //getter function for token category for matching algorithm 
    function getCategory(uint256 tokenID) public view validTokenOnly(tokenID) returns (uint8) {
        return Tokens[tokenID].category;
    }

    //getter function for owner
    function getOwner() public view returns(address) {
        return owner;
    }
    

}