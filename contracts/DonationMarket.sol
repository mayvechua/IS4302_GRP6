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
    uint contract_maintenance; // time tracker, deprecate the withdrawToken() and check for expiration daily

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
        uint expired;
    }
    

    constructor(Token tokenAddress) public {
        tokenContract = tokenAddress;
        owner = msg.sender;
        balanceLimit = 10000;
        autoDeprecate(); // set daily contract check
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
        require(!isStopped, "contract stopped!");
        _;
    }

    //Emergency Stop
    function stopContract() public ownerOnly() {
        isStopped = true;
    }

    function resumeContract() public  ownerOnly()  {
        isStopped = false;
    }

    // deprecate daily to check if the token has expired before allowing withdrawal of tokens
    function autoDeprecate() public {
        contract_maintenance = block.timestamp + 1 days;
    }

    function hasExpired() public view returns (bool) {
        return block.timestamp > contract_maintenance ? true : false;
    }

    modifier isActive {
        require(! hasExpired(), "Not active!");
        _;
    }

    modifier whenDeprecated {
        require(hasExpired(), "has not expired!");
        _;
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


    //Automatic Deprecation of listing and unlisting (check the deadline)
    function autoUnlist() internal whenDeprecated {
        for (uint listId; listId < listingCount; listId++) {
            for (uint req; req < Listings[listId].requestIdList.length; req++) {
                if (block.timestamp > ListingRequests[req].expired) {
                    cancelRequest(req, listId); // request has expired, removed request
                }
            }
        }
        autoDeprecate();
    }

    //Core Functions
    function cancelRequest(uint256 requestId, uint256 listingId) public validTokenOnly(listingId) {
        delete ListingRequests[requestId];
    }

    function unlist(uint256 listingId) public  noReentrancy() validTokenOnly(listingId) tokenDonorOnly(listingId) stoppedInEmergency {
        require(!locked, "No re-entrancy");
        //TODO: unlist from Donation Market
        delete Listings[listingId];
        locked = true;
        require(contractEthBalance >= Listings[listingId].amt, "Insufficient balance in contract pool!");
        tokenContract.transferToken(owner, tx.origin, Listings[listingId].amt);
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
        require(contractEthBalance >= amount, "Insufficient balance in contract pool!");
        tokenContract.transferToken(owner, ListingRequests[requestId].recipientAddress, amount);
        contractEthBalance -= amount;
        locked = false;
        emit transferred(listingId, ListingRequests[requestId].recipientAddress);

        Listings[listingId].amt -= amount;
        if (Listings[listingId].amt  < 1) { 
            emit tokenUnlisting(listingId);
            unlist(listingId);
        }
        return leftoverAmt;

    

    }
    
    //add request to listing
    function addRequest(uint256 listingId, uint256 recipientId, uint256 amt , uint256 deadline, uint256 requestId) public  validTokenOnly(listingId) isActive {
        require(tx.origin != Listings[listingId].donorAddress, "You cannot request for your own token, try unlisting instead!");
        uint expirationTime = block.timestamp + deadline * (1 days);
        state memory newState = state(recipientId, amt, false, deadline, tx.origin, true, expirationTime);
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