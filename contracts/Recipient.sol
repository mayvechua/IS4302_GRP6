// SPDX-License-Identifier: MIT
pragma solidity >=0.6.1;
import "./DonationMarket.sol";

contract Recipient {

    enum recipientState {created, requesting, receivedDonation}

    struct recipient {
        recipientState state;
        address owner;
        string username;
        string pw;
        uint256 wallet; // amt of ether in wallet
        uint256[] activeRequests;
    }

    struct request {
        uint256 requestID;
        uint256 recipientId;
        uint256[] listingsId;
        uint256 amt;
        uint8 deadline;
        string category;
        bool isValue; 
    }

    DonationMarket marketContract;
    address contractOwner;

    bool internal locked = false;
    bool public contractStopped = false;
    uint constant wait_period = 7 days;
    uint contract_maintenance; // time tracker, deprecate the withdrawToken() and check for expiration daily

    uint256 public numRecipients = 0;
    uint256 public numRequests = 0;
    mapping(uint256 => recipient) public recipients;
    mapping(uint256 => request) public requests; // hash(recipientID, username,pw, requestID)
    // mapping(uint256 => listingState[]) public listingsApproved;
    // mapping(uint256 => listingState[]) public listingsNotApproved;
    
   constructor (DonationMarket marketAddress) public {
        marketContract = marketAddress;
        contractOwner = msg.sender;
        autoDeprecate(); // set daily contract check
    }

    //function to create a new recipient, and add to 'recipients' map
    function createRecipient (
        string memory name,
        string memory password
    ) public returns(uint256) {
        uint256[] memory setActiveRequest;
        recipient memory newRecipient = recipient(
            recipientState.created,
            msg.sender, // recipient address
            name,
            password,
            0, // wallet
            setActiveRequest
        );
        
        uint256 newRecipientId = numRecipients++;
        recipients[newRecipientId] = newRecipient; 
        return newRecipientId;   
    }

    event requestedDonation(uint256 recipientId, uint256 listingId, uint256 amt, uint256 deadline, uint256 requestId);
    event completedRequest(uint256 requestId, uint256 listingId);

    //modifier to ensure a function is callable only by its owner    
    modifier ownerOnly(uint256 recipientId) {
        require(recipients[recipientId].owner == msg.sender);
        _;
    }

    modifier stoppedInEmergency {
        if (!contractStopped) _;
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

    // deprecate daily to check if the token has expired before allowing withdrawal of tokens
    function autoDeprecate() public {
        contract_maintenance = block.timestamp + 1 days;
    }

    function hasExpired() public view returns (bool) {
        return block.timestamp > contract_maintenance ? true : false;
    }

    modifier isActive {
        if (! hasExpired()) _;
    }

    modifier whenDeprecated {
        if (hasExpired()) _;
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
        locked = false;
    }

    //when developer (oracle) approve of the proof of usage, it will be tagged to a request to prevent duplicative usage of proof of usage
    function createRequest(uint256 recipientId,uint256 requestedAmt, uint8 deadline, string memory category) public returns (uint256) {
        require(msg.sender == contractOwner, "you are not allowed to use this function");
        require(requestedAmt > 0, "minimum request need to contain at least 1 Token");
        require(requestedAmt < 100, "Requested Amounted hit limit");
        uint256 requestId = numRequests;
        numRequests +=1;
        recipients[recipientId].activeRequests.push(requestId);
        uint256[] memory listings;
        request memory newRequest = request (requestId, recipientId,listings,requestedAmt,deadline, category, true);
        requests[requestId] = newRequest;
        recipients[recipientId].activeRequests.push(requestId);
        return requestId;

    }
    function requestDonation(uint256 recipientId, uint256 listingId, uint256 requestId) public ownerOnly(recipientId) validRecipientId(recipientId) {
        //checks
        require (keccak256(abi.encode(marketContract.getCategory(listingId))) == keccak256(abi.encode(requests[requestId].category)),  
        "you are not eligible to request for this listing");
        request memory requestInfo = requests[requestId];
            for (uint8 i; i< requestInfo.listingsId.length; i++) {
                require(requestInfo.listingsId[i] == listingId, "You have already request for this listing!"); 
            }
        marketContract.addRequest(listingId, recipientId, requestInfo.amt, requestInfo.deadline, requestId);
        requests[requestId].listingsId.push(listingId);

        recipients[recipientId].state = recipientState.requesting;

        emit requestedDonation(recipientId, listingId, requestInfo.amt, requestInfo.deadline, requestId);
    }

    function completeRequest(uint256 requestId, uint256 listingId) public {
        delete requests[requestId];
        emit completedRequest(requestId, listingId);
    }

    function partialCompleteRequest(uint256 requestId, uint256 leftoverAmt) public {
        requests[requestId].amt = leftoverAmt;
    }
    function getWallet(uint256 recipientId) public view ownerOnly(recipientId) validRecipientId(recipientId) returns (uint256) {
        return recipients[recipientId].wallet;
    }

    function getRecipientAddress(uint256 recipientId) public view validRecipientId(recipientId) returns (address) {
        return recipients[recipientId].owner;
    }


    function getRecipeintRequest(uint256 recipientId) public view returns (uint256[] memory) {
        uint256[] memory activeRequest;
        uint8 counter = 0;
        for (uint8 i=0; i < recipients[recipientId].activeRequests.length;  i++) {
            if (requests[recipients[recipientId].activeRequests[i]].isValue) {
                activeRequest[counter] =  recipients[recipientId].activeRequests[i];
                counter ++;
            }
        }
        return activeRequest;
    }

    function getRequestedListing(uint256 requestId) public view returns (uint256[] memory) {
        return requests[requestId].listingsId;
    }
     // self-destruct function 
     function destroyContract() public contractOwnerOnly {
        address payable receiver = payable(contractOwner);
         selfdestruct(receiver);
     }

     

}