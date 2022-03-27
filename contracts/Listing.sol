// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

contract Listing {
    uint256 supplyLimit; 
    uint256 createdCount;
    uint256 returnedCount;
    address owner;
    uint256 contractEthBalance;
    uint256 balanceLimit;
    mapping(uint256 => listing) Listings;
    mapping (bytes32 => uint256[]) recipientRequests; //hash recipient id and listing to requestIDs of each recipient to the lsitings
    mapping (bytes32 => state) ListingRequests; // hash(recipientid and request and listing map state of request, asumming that recipient can only request for 1 token at a time 
   
    struct listing {
        uint256 donorId;
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

    constructor() public {
        owner = msg.sender;
        supplyLimit= 1000;
        balanceLimit = 10000;
        //add recipient and donor contract ?
    }


    //Access Restrictions
    modifier tokenDonorOnly(uint256 listingId) {
        require(tx.origin == Listings[listingId].donorAddress, "You are not the donor of this token!");
        _;
    }


    modifier validTokenOnly(uint256 listingId) {
        require(listingId <= createdCount, "Invalid Token!");
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
    event transferred(uint256 listingId, address recipient);
    event tokenUnlisting(uint256 listingId);
    event requestAdded(uint256 listingId, address recipient);
    event tokenCreated(uint256 listingId);
    event tokenUnlisted(uint256 listingId); 




    //Core Functions
    function unlist(uint256 listingId) public  noReentrancy() validTokenOnly(listingId) tokenDonorOnly(listingId) stoppedInEmergency {
        require(!locked, "No re-entrancy");
        returnedCount += 1;
        //TODO: unlist from Donation Market
        //TODO: store the token in database as historical - is this needed ?
        delete Listings[listingId];
        locked = true;
        require(contractEthBalance >= Listings[listingId].amt, "Insufficient balance in contract pool!");
        payable(tx.origin).transfer(Listings[listingId].amt);
        contractEthBalance -= Listings[listingId].amt;
        locked = false;
        emit tokenUnlisted(listingId);
      
        
    }
    

    //approve function - send eth to recipients, minus amt from token 
    function approve(uint256 recipientId, uint256 listingId) public  noReentrancy() validTokenOnly(listingId) tokenDonorOnly(listingId) stoppedInEmergency returns (uint256){
        require(!locked, "No re-entrancy");

        //transfer money 
        address payable recipientTransferTo = payable( getAddress(listingId, recipientId));
        locked = true;
        uint256 amount = getRequestAmt(listingId, recipientId);
        require(contractEthBalance >=   amount, "Insufficient balance in contract pool!");
        recipientTransferTo.transfer( amount);
        contractEthBalance -= amount;
        locked = false;
        emit transferred(listingId, recipientTransferTo);
        
        Listings[listingId].amt -= amount;
        if (Listings[listingId].amt  < 1) { //TODO: decide the number again
            emit tokenUnlisting(listingId);
            unlist(listingId);
            return Listings[listingId].amt;
          
        }
        return 2; //since we only unlist if less than 1 eth left


    }
    
    //add request to listing
    function addRequest(uint256 listingId, uint256 recipientId, uint256 amt , uint256 deadline, uint256 requestId) public  validTokenOnly(listingId){
        require(tx.origin != Listings[listingId].donorAddress, "You cannot request for your own token, try unlisting instead!");
        state memory newState = state( amt, false, deadline, tx.origin);
        bytes32 hashing1 = keccak256(abi.encode(recipientId, listingId, Listings[listingId].amt, Listings[listingId].category, Listings[listingId].donorId, requestId));
        ListingRequests[hashing1] = newState;
        Listings[listingId].recipientIdList.push(recipientId);
        bytes32 hashing2 = keccak256(abi.encode(recipientId, listingId, Listings[listingId].amt, Listings[listingId].category, Listings[listingId].donorId));
        recipientRequests[hashing2].push(requestId);
        emit requestAdded(listingId, tx.origin);
    }

    // create token + list token on Donation market
    function createToken(uint256 donorId, uint256 amt, string memory category) public payable returns (uint256) {
        require(createdCount - returnedCount <= supplyLimit, "Donation Market Capacity is reached!");
        require(contractEthBalance <= balanceLimit, "The limited amount of ETH stored in this contract is reached!");
        contractEthBalance += amt;
        uint256[] memory recipientList;
        createdCount+=1;
        uint256 listingId = createdCount;
        listing memory newToken = listing(donorId,tx.origin, category, amt,recipientList);
        Listings[listingId]= newToken;
        emit tokenCreated(listingId);

        //TODO:listing of token on donation market 

        return listingId;

    }

    function deleteRequest(uint256 listingId, uint256 requestId, uint256 recipientId) public {
        bytes32 hashing1 = keccak256(abi.encode(recipientId, listingId, Listings[listingId].amt, Listings[listingId].category, Listings[listingId].donorId, requestId));
        delete ListingRequests[hashing1];
         //manual deletion

    }



    //Getter Functions
    //getter function for the amt of each token
     function getTokenAmt(uint256 listingId) public view  validTokenOnly(listingId) returns (uint256) {
        return Listings[listingId].amt;
    }

    //getter function for list of request each token 
    function getListingRecipient(uint256 listingId) public view tokenDonorOnly(listingId) validTokenOnly(listingId) returns (uint256[] memory) {
        return Listings[listingId].recipientIdList;
    }

    //getter function for the request of the recipient in each listing
    function getRecipientRequest(uint256 listingId, uint256 recipientId) public view tokenDonorOnly(listingId) validTokenOnly(listingId) returns (uint256[] memory) {
        bytes32 hashing = keccak256(abi.encode(recipientId, listingId, Listings[listingId].amt, Listings[listingId].category, Listings[listingId].donorId));
        return recipientRequests[hashing];
    }

    //getter function of status for the each request of each token
    function  getStatus(uint256 listingId, uint256 recipientId) public view  validTokenOnly(listingId)returns (bool) {
        bytes32 hashing = keccak256(abi.encode(recipientId, listingId,  Listings[listingId].amt, Listings[listingId].category, Listings[listingId].donorId));
        return  ListingRequests[hashing].isCompleted;
    }

    //getter function of deadline for the each request of each token
    function  getDeadline(uint256 listingId, uint256 recipientId) public view  validTokenOnly(listingId)returns (uint256) {
        bytes32 hashing = keccak256(abi.encode(recipientId, listingId,  Listings[listingId].amt, Listings[listingId].category, Listings[listingId].donorId));
        return  ListingRequests[hashing].deadline;
    }

        //getter function of request for the each request of each token
    function  getRequestAmt(uint256 listingId, uint256 recipientId) public view  validTokenOnly(listingId)returns (uint256) {
        bytes32 hashing = keccak256(abi.encode(recipientId, listingId,  Listings[listingId].amt, Listings[listingId].category, Listings[listingId].donorId));
        return  ListingRequests[hashing].requestAmt;
    }
    
          //getter function of address for the each request of each token
    function  getAddress(uint256 listingId, uint256 recipientId) public view  validTokenOnly(listingId)returns (address) {
        bytes32 hashing = keccak256(abi.encode(recipientId, listingId,  Listings[listingId].amt, Listings[listingId].category, Listings[listingId].donorId));
        return  ListingRequests[hashing].recipientAddress;
    }
    


    //getter function for token category for matching algorithm 
    function getCategory(uint256 listingId) public view validTokenOnly(listingId) returns (string memory) {
        return Listings[listingId].category;
    }

    //getter function for owner
    function getOwner() public view returns(address) {
        return owner;
    }
    

}