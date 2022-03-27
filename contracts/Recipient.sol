// SPDX-License-Identifier: MIT
pragma solidity >=0.6.1;
import "./Listing.sol";

contract Recipient {

    enum recipientState {created, requesting, receivedDonation }

    struct recipient {
        recipientState state;
        address owner;
        string username;
        string pw;
        uint256 wallet; // amt of ether in wallet
        string category;
        uint256[] activeRequests;
        uint256 numRequests;
    }

    struct request {
        uint256[] listingsId;
        uint256 amt;
        uint256 requestID;
        uint8 deadline;
    }

    Listing listingContract;
    address contractOwner;

    bool internal locked = false;
    bool public contractStopped = false;
    uint constant wait_period = 7 days;

    uint256 public numRecipients = 0;
    mapping(uint256 => recipient) public recipients;
    mapping(bytes32 => request) public listingsRequested; // hash(recipientID, username,pw, requestID)
    // mapping(uint256 => listingState[]) public listingsApproved;
    // mapping(uint256 => listingState[]) public listingsNotApproved;
    
   constructor (Listing listingAddress) public {
        listingContract = listingAddress;
        contractOwner = msg.sender;
    }

    //function to create a new recipient, and add to 'recipients' map
    function createRecipient (
        string memory name,
        string memory password,
        string memory category
    ) public returns(uint256) {
        uint256[] memory setActiveRequest;
        recipient memory newRecipient = recipient(
            recipientState.created,
            msg.sender, // recipient address
            name,
            password,
            0, // wallet
            category,
             setActiveRequest,0
        );
        
        uint256 newRecipientId = numRecipients++;
        recipients[newRecipientId] = newRecipient; 
        return newRecipientId;   
    }

    event requestedDonation(uint256 recipientId, uint256 listingId, uint256 amt, uint256 deadline, uint256 requestId);
    event completedToken(uint256 recipientId, uint256 listingId);

    //modifier to ensure a function is callable only by its owner    
    modifier ownerOnly(uint256 recipientId) {
        require(recipients[recipientId].owner == msg.sender);
        _;
    }

    modifier stoppedInEmergency {
        if (!contractStopped) _;
    }

    modifier enableInEmergency {
        if (contractStopped) _;
    }

    modifier contractOwnerOnly {
        require(msg.sender == contractOwner, "only the owner of the contract can call this method!");
        _;
    }

    function toggleContactStopped() public contractOwnerOnly {
        contractStopped = !contractStopped;
    }
    
    modifier validRecipientId(uint256 recipientId) {
        require(recipientId < numRecipients);
        _;
    }

    // mutex: prevent re-entrant
    modifier noReEntrant {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }
    
    // separate the payment to check for re-entrant
    function transferPayment(address payable listing, uint256 amt) noReEntrant public payable {
        listing.transfer(amt);
    }

    //TODO: revisit the logic
    function withdrawTokens(uint256 recipientId) public ownerOnly(recipientId) validRecipientId(recipientId) stoppedInEmergency {
        // TODO: implement automatic depreciation of each listing (7days to cash out for reach approval)! 
        require(recipients[recipientId].wallet > 0, "Invalid amount to be withdrawn from wallet!");
        uint256 listingAmt = recipients[recipientId].wallet;

        address payable receiving = payable(getRecipientAddress(recipientId));
        recipients[recipientId].wallet = 0;

        transferPayment(receiving, listingAmt);

        // unlock after the transaction is completed
        locked = true;
    }

    //when developer (oracle) approve of the proof of usage, it will be tagged to a request to prevent duplicative usage of proof of usage
    function createRequest(uint256 recipientId,uint256 requestedAmt, uint8 deadline) public returns (uint256) {
        require(requestedAmt > 0 ether, "minimum request need to contain at least 1 eth");
        require(requestedAmt < 10 ether, "Requested Amounted hit limit");
        uint256 requestId = recipients[recipientId].numRequests;
        recipients[recipientId].numRequests += 1;
        recipients[recipientId].activeRequests.push(requestId);
        bytes32 hashing = keccak256(abi.encode(recipientId, recipients[recipientId].pw, recipients[recipientId].username, requestId));
        uint256[] memory listings;
        request memory newRequest = request (listings,requestedAmt,requestId,deadline);
        listingsRequested[hashing] = newRequest;
        recipients[recipientId].activeRequests.push(requestId);
        return requestId;

    }
    function requestDonation(uint256 recipientId, uint256 listingId, uint256 requestId) public ownerOnly(recipientId) validRecipientId(recipientId) {
        //checks
        require (keccak256(abi.encode(listingContract.getCategory(listingId))) == keccak256(abi.encode(recipients[recipientId].category)),  
        "you are not eligible to request for this listing");

        bytes32 hashing = keccak256(abi.encode(recipientId, recipients[recipientId].pw, recipients[recipientId].username, requestId));
        request memory requestInfo = listingsRequested[hashing];
            for (uint8 i; i< requestInfo.listingsId.length; i++) {
                require(requestInfo.listingsId[i] == listingId, "You have already request for this listing!"); 
            }
        listingContract.addRequest(listingId, recipientId, requestInfo.amt, requestInfo.deadline, requestId);
        listingsRequested[hashing].listingsId.push(listingId);

        recipients[recipientId].state = recipientState.requesting;

        emit requestedDonation(recipientId, listingId, requestInfo.amt, requestInfo.deadline, requestId);
    }

    function completeRequest(uint256 recipientId, uint256 requestId, uint256 listingId) public {
        bool isIndex = false;
        //manual deletion

        recipients[recipientId].state = recipientState.receivedDonation;

        emit completedToken(recipientId, listingId);
    }

    function getWallet(uint256 recipientId) public view ownerOnly(recipientId) validRecipientId(recipientId) returns (uint256) {
        return recipients[recipientId].wallet;
    }

    function getRecipientAddress(uint256 recipientId) public view validRecipientId(recipientId) returns (address) {
        return recipients[recipientId].owner;
    }

    function getRecipeintRequest(uint256 recipientId) public view returns (uint256[] memory) {
        return recipients[recipientId].activeRequests;
    }

    function getRequestedListing(uint256 recipientId, uint256 requestId) public view returns (uint256[] memory) {
        bytes32 hashing = keccak256(abi.encode(recipientId, recipients[recipientId].pw, recipients[recipientId].username, requestId));
        return listingsRequested[hashing].listingsId;
    }
     // self-destruct function 
     function destroyContract() public contractOwnerOnly {
        address payable receiver = payable(contractOwner);
         selfdestruct(receiver);
     }

     

}