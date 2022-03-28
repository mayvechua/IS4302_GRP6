// SPDX-License-Identifier: MIT
pragma solidity >=0.6.1;
import "./DonationMarket.sol";
import "./Token.sol";

contract Recipient {

    enum recipientState {created, requesting, receivedDonation}

    struct recipient {
        recipientState state;
        address owner;
        string username;
        string pw;
        uint256 wallet; // amt of ether in wallet
        uint256[] activeRequests;
        uint256[] withdrawals;
        
    }

    struct request {
        uint256 requestID;
        uint256 recipientId;
        uint256[] listingsId;
        uint256 amt;
        uint256 partialAmt; // amt that has been completed with partial payment
        uint8 deadline;
        string category;
        bool isValue; 
        uint expireAt; // time from approved to expired 
    }

    Token tokenContract;
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
    mapping(uint256 => request) public withdrawalRequests; // available only for 7 days

    // mapping(uint256 => listingState[]) public listingsApproved;
    // mapping(uint256 => listingState[]) public listingsNotApproved;

    
   constructor (Token tokenAddress, DonationMarket marketAddress) public {
       tokenContract = tokenAddress;
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
        uint256[] memory setWithDrawal;
        recipient memory newRecipient = recipient(
            recipientState.created,
            msg.sender, // recipient address
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
    function transferPayment(address receiver, address donor, uint256 token) noReEntrant internal {
        tokenContract.transfer(receiver, donor, token);
    }

    function cashOutTokens(uint256 amt) internal noReEntrant {
        tokenContract.cashOut(amt);
    }

    function refundToken() public whenDeprecated {

        for (uint recId; recId < numRecipients; recId++) {
            for (uint req; req < recipients[recId].withdrawals.length; req++) {
                if (block.timestamp > withdrawalRequests[recipients[recId].withdrawals[req]].expireAt) {
                    uint256 amt = withdrawalRequests[req].amt;

                    recipients[req].wallet -= amt; // deduct the expired tokens from the recipient's wallet

                    transferPayment(recipients[recId].owner, marketContract.getOwner(), amt); // return the expired tokens to the donor of the tokens (currently is marketcontract first)

                    locked = false;

                    delete withdrawalRequests[req];
                }
            }
        }

        autoDeprecate(); // reset the daily auto deprecation time
        
    }

    //TODO: revisit the logic
    function withdrawTokens(uint256 recipientId) public ownerOnly(recipientId) validRecipientId(recipientId) stoppedInEmergency {
        // TODO: implement automatic depreciation of each listing (7days to cash out for reach approval)! 
        require(recipients[recipientId].wallet > 0, "Invalid amount to be withdrawn from wallet!");
        uint256 listingAmt = recipients[recipientId].wallet;

        recipients[recipientId].wallet = 0;
        delete withdrawalRequests[recipientId]; // all tokens withdrawn
        cashOutTokens(listingAmt);

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
        request memory newRequest = request (requestId, recipientId,listings,requestedAmt, 0, deadline, category, true, block.timestamp);
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
        withdrawalRequests[requestId] = requests[requestId];
        withdrawalRequests[requestId].expireAt = block.timestamp + wait_period; // withdrawal of tokens allowed for 7 days from time of completion 
        withdrawalRequests[requestId].amt += withdrawalRequests[requestId].partialAmt; // final amount to be added into the wallet

        recipients[withdrawalRequests[requestId].recipientId].wallet += withdrawalRequests[requestId].amt;

        delete requests[requestId];
        emit completedRequest(requestId, listingId);
    }

    function partialCompleteRequest(uint256 requestId, uint256 leftoverAmt) public {
        requests[requestId].partialAmt = requests[requestId].amt - leftoverAmt; // to be added to the final amount that can be withdrawn in the wallet
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