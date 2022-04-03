// SPDX-License-Identifier: MIT
pragma solidity >=0.6.1;

contract RecipientStorage {

    // should we use this state for requests instead? cos since each recipient has multiple 
    enum requestState {created, requesting, receivedDonation, expiredRequest}

    // unique beneficiary
    struct recipient {
        // recipientState state;
        address owner;
        string username;
        string pw;
        uint256 wallet; // amt of ether in wallet
        uint256[] activeRequests;
        uint256[] withdrawals;
    }

    // unique instance of required donation
    struct request {
        uint256 requestID;
        uint256 recipientId;
        uint256[] listingsId;
        uint256 amt;
        uint8 deadline;
        string category;
        bool isValue; 
    }

    // unique instance of a completed donation converted into a request for withdrawal into funds 
    struct withdrawal {
        uint256 withdrawalID;
        uint256 recipientId;
        uint256 amt;
        uint expireAt; // time from approved to expired 
        address donorAddress; // to refund the tokens after the expiration date
    }

    address owner = msg.sender; // set deployer as owner of storage
    uint256 public numRecipients = 0;
    uint256 public numRequests = 0;
    mapping(uint256 => recipient) public recipients;
    mapping(uint256 => request) public requests; // requestId -> hash(recipientID, username,pw, requestID)
    mapping(uint256 => withdrawal) public withdrawalRequests; // available only for 7 days

    // mapping(uint256 => listingState[]) public listingsApproved;
    // mapping(uint256 => listingState[]) public listingsNotApproved;


    modifier ownerOnly(uint256 recipientId) {
        require(getRecipientOwner(recipientId) == tx.origin);
        _;
    }

    //function to create a new recipient, and add to 'recipients' map
    function createRecipient (
        string memory name,
        string memory password,
        address sender
    ) public returns(uint256) {
        uint256[] memory setActiveRequest;
        uint256[] memory setWithDrawal;
        recipient memory newRecipient = recipient(
            // recipientState.created,
            tx.origin, // recipient address
            name,
            password,
            0, // wallet
            setActiveRequest,
            setWithDrawal
        );
        uint256 newRecipientId = numRecipients++;
        recipients[newRecipientId] = newRecipient; 
        return newRecipientId;   
    }

    event pushedToActive(uint256[] activeRequests);
    event createdRequest(request newRequest);

    // create a request for a recipient. requestsid will be stored within recipient for access, request itself will be stored in another mapping
    function createRequest(uint256 recipientId,uint256 requestedAmt, uint8 deadline, string memory category) public returns (uint256) {
        require(requestedAmt > 0, "minimum request need to contain at least 1 Token");
        require(requestedAmt < 100, "Requested Amounted hit limit");
        uint256 requestId = numRequests;
        numRequests +=1;
        recipients[recipientId].activeRequests.push(requestId);

        emit pushedToActive(recipients[recipientId].activeRequests);

        uint256[] memory listings;
        requests[requestId] = request(requestId, recipientId,listings,requestedAmt, deadline, category, true);

        emit createdRequest(requests[requestId]);

        return requestId;
    }

    // create a withdrawal
    function createWithdrawal (uint256 requestId) public {
        // request ID will be identical to withdrawal ID
        uint256 withdrawalId = requestId;
        uint256 recipientId = requests[requestId].recipientId;
        uint256 amt = requests[requestId].amt;
        withdrawalRequests[withdrawalId] = withdrawal (withdrawalId, recipientId, amt, block.timestamp, address(0));
    }

    // RECIPIENT LEVEL GETTERS/SETTERS

    // returns address/owner of recipient 
    function getRecipientOwner (uint256 recipientId) public view returns(address) {
        return recipients[recipientId].owner;
    }

    // return wallet amount
    function getRecipientWallet (uint256 recipientId) public view returns(uint256) {
        return recipients[recipientId].wallet;
    }

    // return list of withdrawals per recipient
    function getRecipientWithdrawals (uint256 recipientId) public view returns(uint256[] memory) {
        return recipients[recipientId].withdrawals;
    }

    // return total amount of recipients
    function getTotalRecipients () public view returns(uint256) {
        return numRecipients;
    }

    // return requestIDs of recipeint
    function getRequests (uint256 recipientId) public view returns (uint256[] memory) {
        return recipients[recipientId].activeRequests;
    }

    // modify wallet amount for recipient, operation = "+" for credit, operation = "-" for debit
    function modifyRecipientWallet (uint256 recipientId, uint256 amount, string memory operation) public {
        if (keccak256(abi.encodePacked(operation)) == keccak256(abi.encodePacked("+"))) {
            recipients[recipientId].wallet += amount;
        } else {
            recipients[recipientId].wallet -= amount;
        }
    }

    // empty recipient wallet
    function emptyRecipientWallet (uint256 recipientId) ownerOnly(recipientId) public returns (uint256){
        uint256 walletAmt = recipients[recipientId].wallet;
        recipients[recipientId].wallet = 0;
        return walletAmt;
    }

    // REQUEST LEVEL GETTERS/SETTERS

    // return request category
    function getRequestCategory (uint256 requestId) public view returns(string memory) {
        return requests[requestId].category;
    }

    // return request amount
    function getRequestAmount (uint256 requestId) public view returns(uint256) {
        return requests[requestId].amt;
    }

    // return request deadline
    function getRequestDeadline (uint256 requestId) public view returns(uint8) {
        return requests[requestId].deadline;
    }

    // return bool - true if request exist else false
    function checkRequestValidity(uint256 requestId) public view returns (bool) {
        return requests[requestId].isValue;
    }
    // add unique solicitation attempt
    function addListingToRequest (uint256 requestId, uint256 listingId) public {
        requests[requestId].listingsId.push(listingId);
    }

    

  


    // WITHDRAWAL LEVEL GETTERS/SETTERS

    // return recipient which will receive money upon withdrawal, i.e beneficiary
    function getWithdrawalRecipient (uint256 withdrawalID) public view returns(uint256) {
        return withdrawalRequests[withdrawalID].recipientId;
    }

    // return withdrawal amount to be given to beneficiary
    function getWithdrawalAmount (uint256 withdrawalID) public view returns(uint256) {
        return withdrawalRequests[withdrawalID].amt;
    }

    // return expiry date of withdrawal
    function getWithdrawalExpiry (uint256 withdrawalID) public view returns (uint) {
        return withdrawalRequests[withdrawalID].expireAt;
    }

    // return original donor, where tokens will be refunded to upon withdrawal expiry
    function getWithdrawalDonor (uint256 requestId) public view returns (address) {
        return withdrawalRequests[requestId].donorAddress;
    }

    // set expiry date 
    function addWithdrawalExpiry (uint256 withdrawalId, uint expiry) public {
        withdrawalRequests[withdrawalId].expireAt = expiry;
    }

    // set refund address for withdrawal
    function addWithdrawalRefundAddress (uint256 withdrawalId, address add) public {
        withdrawalRequests[withdrawalId].donorAddress = add;
    }


    // OTHER HELPER FUNCTIONS

    // remove request from tracking in mapping
    function removeRequest (uint256 requestId) public {
        delete requests[requestId];
    }

    // remove withdrawal from tracking in mapping
    function removeWithdrawal (uint256 withdrawalId) public {
        delete withdrawalRequests[withdrawalId];
    }

    // Check if requestid has already exist in the listing to prevent one request id from requesting multiple times in one listing 
    function verifyRequestListing (uint256 requestId, uint256 listingId) public view returns(bool) {
        bool verified = false;
        for (uint8 i; i< requests[requestId].listingsId.length; i++) {
            if (requests[requestId].listingsId[i] == listingId) {
                verified = true;
                break;
            } 
        }
        return verified;
    }




}