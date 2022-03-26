// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

contract Token {
    uint256 supplyLimit; 
    uint256 createdCount;
    uint256 returnedCount;
    address owner;
    uint256 contractEthBalance;
    uint256 balanceLimit;
    mapping(uint256 => token) Tokens;
    mapping (bytes32 => state) Tokenrequests; // hash(recipientid and tokenid) map state of request, asumming that recipient can only request for 1 token at a time 
   
    struct token {
        uint256 donorID;
        address donorAddress;
        string category;
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
        require(tokenID <= createdCount, "Invalid Token!");
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
        require(newLimit >500 ,"Too low of a limit!");
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
    event tokenUnlisted(uint256 tokenID); 




    //Core Functions
    function unlist(uint256 tokenID) public  noReentrancy() validTokenOnly(tokenID) tokenDonorOnly(tokenID) stoppedInEmergency {
        require(!locked, "No re-entrancy");
        returnedCount += 1;
        //TODO: unlist from Donation Market
        //TODO: store the token in database as historical - is this needed ?
        delete Tokens[tokenID];
        locked = true;
        require(contractEthBalance >= Tokens[tokenID].amt, "Insufficient balance in contract pool!");
        payable(tx.origin).transfer(Tokens[tokenID].amt);
        contractEthBalance -= Tokens[tokenID].amt;
        locked = false;
        emit tokenUnlisted(tokenID);
      
        
    }
    

    //approve function - send eth to recipients, minus amt from token 
    function approve(uint256 recipientID, uint256 tokenID) public payable noReentrancy() validTokenOnly(tokenID) tokenDonorOnly(tokenID) stoppedInEmergency returns (uint256){
        require(!locked, "No re-entrancy");
        bytes32 hashing = keccak256(abi.encode(recipientID, tokenID,  Tokens[tokenID].amt, Tokens[tokenID].category, Tokens[tokenID].donorID));
        Tokenrequests[hashing].isCompleted = true;
        address payable recipientTransferTo = payable( getAddress(tokenID, recipientID));
        locked = true;
        uint256 amount = getRequestAmt(tokenID, recipientID);
        require(contractEthBalance >=  amount, "Insufficient balance in contract pool!");
        recipientTransferTo.transfer( amount);
        contractEthBalance -= amount;
        locked = false;
        emit transferred(tokenID, recipientTransferTo);
        
        Tokens[tokenID].amt -= amount;
        if (Tokens[tokenID].amt  < 1) { //TODO: decide the number again
            emit tokenUnlisting(tokenID);
            unlist(tokenID);
            return Tokens[tokenID].amt;
          
        }
        return 2; //since we only unlist if less than 1 eth left


    }
    
    //add request to token  
    function addRequest(uint256 tokenID, uint256 recipientID, uint256 amt , uint256 deadline) public  validTokenOnly(tokenID){
        require(tx.origin != Tokens[tokenID].donorAddress, "You cannot request for your own token, try unlisting instead!");
        state memory newState = state( amt, false, deadline, tx.origin);
        bytes32 hashing = keccak256(abi.encode(recipientID, tokenID, Tokens[tokenID].amt, Tokens[tokenID].category, Tokens[tokenID].donorID));
        Tokenrequests[hashing] = newState;
        Tokens[tokenID].recipientIdList.push(recipientID);
        emit requestAdded(tokenID, tx.origin);
    }

    // create token + list token on Donation market
    function createToken(uint256 donorID, uint256 amt, string memory category) public payable returns (uint256) {
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
    function  getStatus(uint256 tokenID, uint256 recipientID) public view  validTokenOnly(tokenID)returns (bool) {
        bytes32 hashing = keccak256(abi.encode(recipientID, tokenID,  Tokens[tokenID].amt, Tokens[tokenID].category, Tokens[tokenID].donorID));
        return  Tokenrequests[hashing].isCompleted;
    }

    //getter function of deadline for the each request of each token
    function  getDeadline(uint256 tokenID, uint256 recipientID) public view  validTokenOnly(tokenID)returns (uint256) {
        bytes32 hashing = keccak256(abi.encode(recipientID, tokenID,  Tokens[tokenID].amt, Tokens[tokenID].category, Tokens[tokenID].donorID));
        return  Tokenrequests[hashing].deadline;
    }

        //getter function of request for the each request of each token
    function  getRequestAmt(uint256 tokenID, uint256 recipientID) public view  validTokenOnly(tokenID)returns (uint256) {
        bytes32 hashing = keccak256(abi.encode(recipientID, tokenID,  Tokens[tokenID].amt, Tokens[tokenID].category, Tokens[tokenID].donorID));
        return  Tokenrequests[hashing].requestAmt;
    }
    
          //getter function of address for the each request of each token
    function  getAddress(uint256 tokenID, uint256 recipientID) public view  validTokenOnly(tokenID)returns (address) {
        bytes32 hashing = keccak256(abi.encode(recipientID, tokenID,  Tokens[tokenID].amt, Tokens[tokenID].category, Tokens[tokenID].donorID));
        return  Tokenrequests[hashing].recipientAddress;
    }
    


    //getter function for token category for matching algorithm 
    function getCategory(uint256 tokenID) public view validTokenOnly(tokenID) returns (string memory) {
        return Tokens[tokenID].category;
    }

    //getter function for owner
    function getOwner() public view returns(address) {
        return owner;
    }

    //getter function for contract ether balance (to be deleted)
    function getBalance() public view returns (uint256) {
        return contractEthBalance;
    }
    

}