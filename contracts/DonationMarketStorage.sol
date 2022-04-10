// SPDX-License-Identifier: MIT
pragma solidity >=0.6.1;

contract DonationMarketStorage {

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

    address owner = msg.sender; // set deployer as owner of storage
    mapping(uint256 => listing) Listings;
    mapping (uint256 => state) ListingRequests; 
    //Access Restriction 
    modifier contractOwnerOnly() {
        require(
            msg.sender == owner,
            "you are not allowed to use this function"
        );
        _;
    }
    
    //Security Functions
    
    //Self-destruct function
    bool internal locked = false;
    function destroyContract() public contractOwnerOnly {
        address payable receiver = payable(owner);
        selfdestruct(receiver);
    }

    
    //getter function for owner
    function getOwner() public view returns(address) {
        return owner;
    }

    // LISTING LEVEL

    // add new listing to mapping
    function addListing(uint256 listingId, uint256 donorId, address donorAddress, string memory category, uint256 amt) public {
        uint256[] memory recipientList;
        listing memory newListing = listing(donorId, donorAddress, category, amt, recipientList, true);
        Listings[listingId]= newListing;
    }

    // getter function to return list of requests belong to listing
    function getListingRequests(uint256 listingId) public view returns (uint256[] memory) {
        return Listings[listingId].requestIdList;
    }

    // getter function to return listing amount
    function getListingAmount(uint256 listingId) public view returns (uint256) {
        return Listings[listingId].amt;
    }

    // getter function to return listing's donor address
    function getListingDonorAddress(uint256 listingId) public view returns (address) {
        return Listings[listingId].donorAddress;
    }

    // getter function to return listing category
    function getListingCategory(uint256 listingId) public view returns (string memory) {
        return Listings[listingId].category;
    }

    //getter function to check if lsiting still avaliable 
    function checkListing(uint256 listingId) public view returns (bool) {
        return Listings[listingId].isValue;
    }
    
    //setter function to remove request from mapping
    function removeListing(uint256 listingId) public {
        delete Listings[listingId];
    }

    // modify listing amount, operation = "+" for credit, operation = "-" for debit
    function modifyListingAmount (uint256 listingId, uint256 amount, string memory operation) public {
        if (keccak256(abi.encodePacked(operation)) == keccak256(abi.encodePacked("+"))) {
            Listings[listingId].amt += amount;
        } else {
            Listings[listingId].amt -= amount;
        }
    }

    // REQUEST LEVEL

    // add new request to mapping and to corresponding listing
    function addRequest(uint256 requestId, uint256 listingId, uint256 recipientId, uint256 requestAmt,  uint256 deadline, address recipientAddress, uint expired) public {
        state memory newState = state(recipientId, requestAmt, false, deadline, recipientAddress, true, expired);
        ListingRequests[requestId] = newState;
        Listings[listingId].requestIdList.push(requestId);
    }

    //getter function of status for the each request of each listing
    function getRequestStatus(uint256 requestId) public view returns (bool) {
        return ListingRequests[requestId].isCompleted;
    }

    //getter function of deadline for the each request of each listing
    function getRequestDeadline(uint256 requestId) public view  returns (uint256) {
        return ListingRequests[requestId].deadline;
    }

    //getter function of request for the each request of each listing
    function getRequestAmt(uint256 requestId) public view  returns (uint256) {
        return ListingRequests[requestId].requestAmt;
    }
    
    //getter function of address for the each request of each listing
    function getRequestRecipientAddress(uint256 requestId) public view returns (address) {
        return ListingRequests[requestId].recipientAddress;
    }

    //getter function of request expiry
    function getRequestExpiry(uint256 requestId) public view returns (uint) {
        return ListingRequests[requestId].expired;
    }

    //getter function to check if request still avaliable 
    function checkRequest(uint256 requestId) public view returns (bool) {
        return ListingRequests[requestId].isValue;
    }

    //setter function to remove request from mapping
    function removeRequest(uint256 requestId) public {
        delete ListingRequests[requestId];
    }

}