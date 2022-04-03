// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;
import "./Token.sol";
import "./DonationMarketStorage.sol";

contract DonationMarket {
    address owner;
    uint256 contractEthBalance;
    uint256 listingCount;
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

    modifier validListingOnly(uint256 listingId) {
        require(donationMarketStorage.checkListing(listingId), "Invalid Listing!");
         _;
    }

    //Emergency Stop
    function toggleContactStopped() public ownerOnly() {
        isStopped = !isStopped;
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

    
    function selfDestruct() public ownerOnly() {
        address payable addr = payable(owner);
        selfdestruct(addr); 
    }

    //Events
    event transferred(uint256 listingId, address recipient);
    event listingUnlisting(uint256 listingId);
    event requestAdded(uint256 listingId, uint256 requestId);
    event listingCreated(uint256 listingId);
    event listingUnlisted(uint256 listingId); 


    //Automatic Deprecation of listing and unlisting (check the deadline)
    function autoUnlist() internal whenDeprecated {
        for (uint listId; listId < listingCount; listId++) {
            for (uint req; req < donationMarketStorage.getListingRequests(req).length; req++) {
                if (block.timestamp > donationMarketStorage.getRequestExpiry(req)) {
                    cancelRequest(req, listId); // request has expired, removed request
                }
            }
        }
        autoDeprecate();
    }

    //Core Functions 
    function cancelRequest(uint256 requestId, uint256 listingId) public validListingOnly(listingId) {
        donationMarketStorage.removeRequest(requestId);
    }

    function unlist(uint256 listingId) public  noReentrancy() validListingOnly(listingId) listingDonorOnly(listingId) stoppedInEmergency {
        require(!locked, "No re-entrancy");
        //TODO: unlist from Donation Market
        donationMarketStorage.removeListing(listingId);
        locked = true;
        tokenContract.transferToken(owner, tx.origin, donationMarketStorage.getListingAmount(listingId));
        emit transferred(listingId, tx.origin);
        contractEthBalance -= donationMarketStorage.getListingAmount(listingId);
        locked = false;
        emit listingUnlisted(listingId);
    }
    

    //approve function - send eth to recipients, minus amt from listing 
    // there will be no partial transfer! 
    function approve(uint256 requestId, uint256 listingId) public  noReentrancy() validListingOnly(listingId) listingDonorOnly(listingId) stoppedInEmergency {
        require(donationMarketStorage.checkRequest(requestId), "request has been taken down");
        //transfer tokens
        locked = true;
        uint256 amount = donationMarketStorage.getRequestAmt(requestId);
        require(donationMarketStorage.getListingAmount(listingId) >= amount, "Insufficient balance in listing to approve this transaction");
        tokenContract.transferToken(owner, donationMarketStorage.getRequestRecipientAddress(requestId), amount);
        contractEthBalance -= amount ;
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
        uint expirationTime = block.timestamp + deadline * (1 days);
        donationMarketStorage.addRequest(requestId, listingId, recipientId, amt, deadline, tx.origin, expirationTime);
        emit requestAdded(listingId, requestId);
    }


    // create Listing + list 
    function createListing(uint256 donorId, uint256 amt, string memory category) public returns (uint256) {
        contractEthBalance += amt;
        uint256 listingId = listingCount;
        listingCount += 1;
        donationMarketStorage.addListing(listingId, donorId, tx.origin, category, amt);
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

    
        // self-destruct function 
     function destroyContract() public ownerOnly {
        address payable receiver = payable(owner);
         selfdestruct(receiver);
     }


}