// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;
import "./Token.sol";
import "./DonationMarketStorage.sol";

contract DonationMarket {
    address owner;
    Token tokenContract;
    DonationMarketStorage donationMarketStorage;
    uint contract_maintenance; // time tracker, deprecate the withdrawToken() and check for expiration daily

    constructor(Token tokenAddress, DonationMarketStorage storageAddress) public {
        tokenContract = tokenAddress;
        donationMarketStorage = storageAddress;
        owner = msg.sender;
        autoDeprecate(); // set daily contract check
    }

    //Access Restrictions
    modifier listingDonorOnly(uint256 listingId) {
        require(tx.origin == donationMarketStorage.getListingDonorAddress(listingId), "You are not the donor of this listing!");
        _;
    }

    modifier contractOwnerOnly() {
        require(msg.sender == owner, "You are not allowed to use this function!");
         _;
    }
    modifier noReentrancy() {
        require(!locked, "No re-entrancy");
        _;
    }


    modifier stoppedInEmergency {
        require(!isStopped, "contract stopped!");
        _;
    }
      modifier isActive {
        require(! hasExpired(), "Not active!");
        _;
    }

    modifier whenDeprecated {
        require(hasExpired(), "has not expired!");
        _;
    }
    modifier validListingOnly(uint256 listingId) {
        require(donationMarketStorage.checkListing(listingId), "Invalid Listing!");
         _;
    }

    //Security Functions 

    bool internal locked;
    bool isStopped = false;


    //Emergency Stop
    function toggleContactStopped() public contractOwnerOnly {
        isStopped = !isStopped;
    }

    // Deprecate daily to check if the token has expired before allowing withdrawal of tokens
    function autoDeprecate() public {
        contract_maintenance = block.timestamp + 1 days;
    }
    
    //Automatic Deprecation of requests(check the deadline)
    function autoRemoveExpiredRequest() internal whenDeprecated {
        uint256[] memory activeListing = getAllListings();
        for (uint8 i; i < activeListing.length; i++) {
            uint256 listId = activeListing[i];
            uint256[] memory requestId = getActiveRequest(listId);
            for (uint req; req < requestId.length; req++) {
                if ( requestId[req] != 0 
                && block.timestamp > donationMarketStorage.getRequestExpiry(requestId[req])) {
                    cancelRequest(req, listId); // request has expired, removed request
                }
            }
        }
        autoDeprecate();
    }

    //Checking process of whether or not the request have expired 
    function hasExpired() public view returns (bool) {
        return block.timestamp > contract_maintenance ? true : false;
    }

    //Self Destruct Function of contract 
    function selfDestruct() public contractOwnerOnly {
        address payable addr = payable(owner);
        selfdestruct(addr); 
    }

    //Events
    event transferred(uint256 listingId, address recipient);
    event listingUnlisting(uint256 listingId);
    event requestAdded(uint256 listingId, uint256 requestId);
    event listingCreated(uint256 listingId);
    event listingUnlisted(uint256 listingId); 



    //Core Functions 

    // Allow for removal of request in all the listing that this request has requested.
    function cancelRequest(uint256 requestId, uint256 listingId) public validListingOnly(listingId) {
        donationMarketStorage.removeRequest(requestId);
    }

    function unlist(uint256 listingId) public  noReentrancy() validListingOnly(listingId) listingDonorOnly(listingId) stoppedInEmergency {
        require(!locked, "No re-entrancy");
        donationMarketStorage.removeListing(listingId);
        locked = true;
        tokenContract.transferToken(owner, tx.origin, donationMarketStorage.getListingAmount(listingId));
        emit transferred(listingId, tx.origin);
        locked = false;
        emit listingUnlisted(listingId);
    }
    

    //Approve function : send tokens to recipients, remove request from all other listing to prevent multiple trasnfer of that request. 
    // Re-entrancy security function since transferring of tokens occur here
    // there will be no partial transfer of tokens. (either all requested tokens or none)
    function approve(uint256 requestId, uint256 listingId) public  noReentrancy() validListingOnly(listingId) listingDonorOnly(listingId) stoppedInEmergency {
        require(donationMarketStorage.checkRequest(requestId), "request has been taken down");
        //transfer tokens
        locked = true;
        uint256 amount = donationMarketStorage.getRequestAmt(requestId);
        require(donationMarketStorage.getListingAmount(listingId) >= amount, "Insufficient balance in listing to approve this transaction");
        tokenContract.transferToken(owner, donationMarketStorage.getRequestRecipientAddress(requestId), amount);
        locked = false;
        emit transferred(listingId, donationMarketStorage.getRequestRecipientAddress(requestId));
        // transfer end, check 
        donationMarketStorage.removeRequest(requestId);
        donationMarketStorage.modifyListingAmount(listingId, amount, "-");

        if (donationMarketStorage.getListingAmount(listingId) < 1) {
            emit listingUnlisting(listingId);
            unlist(listingId);
        }

    }
    
    //add request to listing
    function addRequest(uint256 listingId, uint256 recipientId, uint256 amt , uint256 deadline, uint256 requestId) public  validListingOnly(listingId) isActive {
        require(tx.origin != donationMarketStorage.getListingDonorAddress(listingId), "You cannot request for your own listing, try unlisting instead!");
        uint expirationTime = deadline;
        donationMarketStorage.addRequest(requestId, listingId, recipientId, amt, deadline, tx.origin, expirationTime);
        emit requestAdded(listingId, requestId);
    }


    // list the listing created by donor 
    function createListing(uint256 donorId, uint256 amt, string memory category) public returns (uint256) {
        uint256 listingId = donationMarketStorage.getListingCount();
        donationMarketStorage.addListing(donorId, tx.origin, category, amt);
        emit listingCreated(listingId);
        return listingId;
    }

    // getters in place to ensure that other contracts cannot directly access the donation market storage data layer
    // and to enforce access modifiers for external contracts
    //getter function for the requests in each listing
    function getRecipientRequest(uint256 listingId) public view listingDonorOnly(listingId) validListingOnly(listingId) returns (uint256[] memory) {
        uint256[] memory requests = donationMarketStorage.getListingRequests(listingId);
        uint256[] memory activeRequest = new uint256[] ( requests.length);
        uint8 counter = 0;
        for (uint8 i=0; i <  requests.length;  i++) {
            uint256 id = requests[i];
            if (! donationMarketStorage.getRequestStatus(id)) {
                activeRequest[counter] =  id;
                counter ++;
            }
        }
        return activeRequest;
    }

    //getter function for listing category for matching algorithm 
    function getCategory(uint256 listingId) public view validListingOnly(listingId) returns (string memory) {
        return donationMarketStorage.getListingCategory(listingId);
    }

    //getter function to check if lsiting still avaliable 
    function checkListing(uint256 listingId) public view returns (bool) {
        return donationMarketStorage.checkListing(listingId);
    }

    //getter function to get owner of contract
    function getOwner() public view returns (address) {
        return owner;
    }

    //getter functions to get all active listing in the market
    function getAllListings() public view returns (uint256[] memory) {
        uint256[] memory allActiveListing = new uint256[] (donationMarketStorage.getActiveListingCount());
        uint256[] memory allListingId = donationMarketStorage.getAllListing();
        uint8 counter = 0;
        for (uint8 i =0; i < allListingId.length; i++) {
            if (donationMarketStorage.checkListing(allListingId[i])) {
                allActiveListing[counter] = allListingId[i];
                counter++;
            }
             
        }
        return allActiveListing;
    }


    //get all active request of listing 
    function getActiveRequest(uint256 listingId)  public view validListingOnly(listingId) listingDonorOnly(listingId)  returns (uint256[] memory) {
        uint256[] memory allRequestId = donationMarketStorage.getListingRequests(listingId);
        uint256[] memory activeRequests = new uint256[] (allRequestId.length);
        for (uint8 i ; i < allRequestId.length ; i++) {
            if (donationMarketStorage.checkRequest(allRequestId[i])) {
                activeRequests[i] = allRequestId[i];
            } else {
                activeRequests[i]  = 0; //frontend to filter off 0 (representing inactive request) as request id start with 1
            }
        }
        return activeRequests;
         
    }
}