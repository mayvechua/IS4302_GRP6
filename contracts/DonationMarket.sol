// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;
import "./Token.sol";

contract DonationMarket {
    address owner;
    uint256 contractEthBalance;
    uint256 balanceLimit;
    uint256 listingCount;
    mapping(uint256 => listing) Listings;
    mapping (uint256 => state) ListingRequests; 
    Token tokenContract;

    struct listing {
        uint256 donorId;
        address donorAddress;
        string category;
        uint256 amt;
        uint256[] requestIdList;
        bool isValue;

    }

    struct state {
        uint256 recipientId;
        uint256 requestAmt;
        bool isCompleted;
        uint256 deadline;
        address recipientAddress;
        bool isValue;
    }
    

    constructor(Token tokenAddress) public {
        tokenContract = tokenAddress;
        owner = msg.sender;
        balanceLimit = 10000;
        //add recipient and donor contract ?
    }


    //Access Restrictions
    modifier tokenDonorOnly(uint256 listingId) {
        require(tx.origin == Listings[listingId].donorAddress, "You are not the donor of this token!");
        _;
    }


    modifier validTokenOnly(uint256 listingId) {
        require(Listings[listingId].isValue, "Invalid Token!");
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
    event requestAdded(uint256 listingId, uint256 requestId);
    event tokenCreated(uint256 listingId);
    event tokenUnlisted(uint256 listingId); 




    //Core Functions
    function unlist(uint256 listingId) public  noReentrancy() validTokenOnly(listingId) tokenDonorOnly(listingId) stoppedInEmergency {
        require(!locked, "No re-entrancy");
        //TODO: unlist from Donation Market
        delete Listings[listingId];
        locked = true;
        require(contractEthBalance >= Listings[listingId].amt, "Insufficient balance in contract pool!");
        tokenContract.transfer(owner, tx.origin, Listings[listingId].amt);
        contractEthBalance -= Listings[listingId].amt;
        locked = false;
        emit tokenUnlisted(listingId);
      
        
    }
    

    //approve function - send eth to recipients, minus amt from token 
    function approve(uint256 requestId, uint256 listingId) public  noReentrancy() validTokenOnly(listingId) tokenDonorOnly(listingId) stoppedInEmergency returns (uint256){
        require(!locked, "No re-entrancy");
        require(ListingRequests[requestId].isValue, "request has been taken down");
        //transfer tokens
        locked = true;
        uint256 amount = ListingRequests[requestId].requestAmt;
        uint256 leftoverAmt= Listings[listingId].amt - amount;
        require(contractEthBalance >= amount - leftoverAmt, "Insufficient balance in contract pool!");
        tokenContract.transfer(owner, ListingRequests[requestId].recipientAddress, amount - leftoverAmt);
        contractEthBalance -= amount - leftoverAmt;
        locked = false;
        emit transferred(listingId, ListingRequests[requestId].recipientAddress);
        // transfer end, check 
        if (Listings[listingId].amt - amount < 0) {
            ListingRequests[requestId].requestAmt = leftoverAmt; 
       
        } else {
            delete ListingRequests[requestId]; 
        }
        Listings[listingId].amt -= amount;
        if (Listings[listingId].amt  < 1) { 
            emit tokenUnlisting(listingId);
            unlist(listingId);
        }
        return leftoverAmt;

    

    }
    
    //add request to listing
    function addRequest(uint256 listingId, uint256 recipientId, uint256 amt , uint256 deadline, uint256 requestId) public  validTokenOnly(listingId){
        require(tx.origin != Listings[listingId].donorAddress, "You cannot request for your own token, try unlisting instead!");
        state memory newState = state(recipientId, amt, false, deadline, tx.origin, true);
        ListingRequests[requestId] = newState;
        Listings[listingId].requestIdList.push(requestId);
        emit requestAdded(listingId, requestId);
    }

    // create token + list 
    function createToken(uint256 donorId, uint256 amt, string memory category) public payable returns (uint256) {
        require(contractEthBalance <= balanceLimit, "The limited amount of ETH stored in this contract is reached!");
        contractEthBalance += amt;
        uint256[] memory recipientList;
        uint256 listingId = listingCount;
        listingCount += 1;
        listing memory newToken = listing(donorId,tx.origin, category, amt,recipientList, true);
        Listings[listingId]= newToken;
        emit tokenCreated(listingId);
        return listingId;

    }




    //Getter Functions
    //getter function for the amt of each token
     function getTokenAmt(uint256 listingId) public view  validTokenOnly(listingId) returns (uint256) {
        return Listings[listingId].amt;
    }


    //getter function for the requests in each listing
    function getRecipientRequest(uint256 listingId) public view tokenDonorOnly(listingId) validTokenOnly(listingId) returns (uint256[] memory) {
        uint256[] memory activeRequest;
        uint8 counter = 0;
        for (uint8 i=0; i < Listings[listingId].requestIdList.length;  i++) {
            if (ListingRequests[Listings[listingId].requestIdList[i]].isValue) {
                activeRequest[counter] =  Listings[listingId].requestIdList[i];
                counter ++;
            }
        }
        return activeRequest;
    }

    //getter function of status for the each request of each token
    function  getStatus(uint256 requestId) public view returns (bool) {
        return  ListingRequests[requestId].isCompleted;
    }

    //getter function of deadline for the each request of each token
    function getDeadline(uint256 requestId) public view  returns (uint256) {
        return   ListingRequests[requestId].deadline;
    }

        //getter function of request for the each request of each token
    function  getRequestAmt(uint256 requestId) public view  returns (uint256) {
        return  ListingRequests[requestId].requestAmt;
    }
    
          //getter function of address for the each request of each token
    function  getAddress(uint256 requestId) public view returns (address) {
        return  ListingRequests[requestId].recipientAddress;
    }
    

    //getter function for token category for matching algorithm 
    function getCategory(uint256 listingId) public view validTokenOnly(listingId) returns (string memory) {
        return Listings[listingId].category;
    }

    //getter function for owner
    function getOwner() public view returns(address) {
        return owner;
    }

    //getter function to check if lsiting still avaliable 
    function checkListing(uint256 listingId) public view returns (bool) {
        return Listings[listingId].isValue;
    }
    
        // self-destruct function 
     function destroyContract() public ownerOnly {
        address payable receiver = payable(owner);
         selfdestruct(receiver);
     }

    //Emergency 
    function toggleContactStopped() public  ownerOnly {
        isStopped= !isStopped;
    }
}