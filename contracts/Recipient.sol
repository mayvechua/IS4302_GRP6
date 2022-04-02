// SPDX-License-Identifier: MIT
pragma solidity >=0.6.1;
import "./DonationMarket.sol";
import "./Token.sol";
import "./RecipientStorage.sol";

contract Recipient {

    Token tokenContract;
    DonationMarket marketContract;
    RecipientStorage recipientStorage;
    address contractOwner;

    bool internal locked = false;
    bool public contractStopped = false;
    uint constant wait_period = 7 days;
    uint contract_maintenance; // time tracker, deprecate the withdrawToken() and check for expiration daily

    
   constructor (Token tokenAddress, DonationMarket marketAddress, RecipientStorage storageAddress) public {
        tokenContract = tokenAddress;
        marketContract = marketAddress;
        recipientStorage = storageAddress;
        contractOwner = msg.sender;
        autoDeprecate(); // set daily contract check
    }

    //function to create a new recipient, and add to 'recipients' map
    function createRecipient (
        string memory name,
        string memory password
    ) public returns(uint256) {
        uint256 newRecipientId = recipientStorage.createRecipient(name, password); 
        return newRecipientId;   
    }

    event requestedDonation(uint256 recipientId, uint256 listingId, uint256 amt, uint256 deadline, uint256 requestId);
    event completedRequest(uint256 requestId, uint256 listingId);

    //modifier to ensure a function is callable only by its owner    
    modifier ownerOnly(uint256 recipientId) {
        require(recipientStorage.getRecipientOwner(recipientId) == msg.sender);
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
        require(recipientId < recipientStorage.getTotalRecipients());
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
    function transferPayment(address sender, address receiver, uint256 token) noReEntrant internal {
        tokenContract.transferToken(sender, receiver, token);
    }

    function cashOutTokens(uint256 amt) internal noReEntrant {
        tokenContract.cashOut(amt);
    }

    function refundToken() public whenDeprecated {
        for (uint recId; recId < recipientStorage.getTotalRecipients(); recId++) {
            uint256[] memory withdrawals = recipientStorage.getRecipientWithdrawals(recId);
            for (uint req; req < withdrawals.length; req++) {
                uint256 withdrawalId = withdrawals[req];
                if (block.timestamp > recipientStorage.getWithdrawalRecipient(withdrawalId)) {
                    uint256 amt = recipientStorage.getWithdrawalAmount(withdrawalId);
                    recipientStorage.modifyRecipientWallet(recipientStorage.getWithdrawalRecipient(withdrawalId), amt, "-"); // deduct the expired tokens from the recipient's wallet
                    transferPayment(recipientStorage.getRecipientOwner(recId), recipientStorage.getWithdrawalDonor(withdrawalId), amt); // return the expired tokens to the donor of the tokens (currently is marketcontract first)

                    locked = false;

                    recipientStorage.removeWithdrawal(withdrawalId);
                }
            }
        }

        autoDeprecate(); // reset the daily auto deprecation time
        
    }

    //TODO: revisit the logic
    function withdrawTokens(uint256 recipientId) public ownerOnly(recipientId) validRecipientId(recipientId) stoppedInEmergency {
        // TODO: implement automatic depreciation of each listing (7days to cash out for reach approval)! 

        uint256 listingAmt = recipientStorage.getRecipientWallet(recipientId);
        require(listingAmt > 0, "Invalid amount to be withdrawn from wallet!");
        

        recipientStorage.emptyRecipientWallet(recipientId);
        recipientStorage.removeWithdrawal(recipientId);
        cashOutTokens(listingAmt);

        // unlock after the transaction is completed
        locked = false;
    }

    //when developer (oracle) approve of the proof of usage, it will be tagged to a request to prevent duplicative usage of proof of usage
    function createRequest(uint256 recipientId,uint256 requestedAmt, uint8 deadline, string memory category) public returns (uint256) {
        require(msg.sender == contractOwner, "you are not allowed to use this function");
        uint256 requestId = recipientStorage.createRequest(recipientId, requestedAmt, deadline, category);
        return requestId;
    }

    function requestDonation(uint256 recipientId, uint256 listingId, uint256 requestId) public ownerOnly(recipientId) validRecipientId(recipientId) {
        //checks
        require (keccak256(abi.encode(marketContract.getCategory(listingId))) == keccak256(abi.encode(recipientStorage.getRequestCategory(requestId))),  
        "you are not eligible to request for this listing");
        require(recipientStorage.verifyRequestListing(requestId, listingId), "You have already requested for this listing");
        uint8 deadline = recipientStorage.getRequestDeadline(requestId);
        uint256 amount = recipientStorage.getRequestAmount(requestId);
        marketContract.addRequest(listingId, recipientId, amount, deadline, requestId);
        recipientStorage.addListingToRequest(requestId, listingId);
        // recipients[recipientId].state = recipientState.requesting;
        emit requestedDonation(recipientId, listingId, amount, deadline, requestId);
    }

    function completeRequest(uint256 requestId, uint256 listingId, address donorAddress) public {
        recipientStorage.createWithdrawal(requestId); // add withdrawal
        uint256 withdrawalId = requestId;
        recipientStorage.addWithdrawalExpiry(withdrawalId, block.timestamp + wait_period); // withdrawal of tokens allowed for 7 days from time of completion 
        
        // get recipient of withdrawal
        uint256 recipientId = recipientStorage.getWithdrawalRecipient(withdrawalId);
        // facilitate withdrawal
        uint256 amount = recipientStorage.getWithdrawalAmount(withdrawalId);
        recipientStorage.modifyRecipientWallet(recipientId, amount, "+");
        recipientStorage.addWithdrawalRefundAddress(withdrawalId, donorAddress);
        // remove request
        recipientStorage.removeRequest(requestId);

        emit completedRequest(requestId, listingId);
    }

    // function cancelRequest(uint256 recipientId, uint256 requestId, uint256 listingId) public {
    //     delete requests[requestId];
    //     delete recipients[recipientId].activeRequests[requestId]; // request no longer active
    //     marketContract.cancelRequest(requestId, listingId); // remove request from market listing
    //     numRequests -=1;
    // }

    function getWallet(uint256 recipientId) public view ownerOnly(recipientId) validRecipientId(recipientId) returns (uint256) {
        return recipients[recipientId].wallet;
    }


    /*

    UNUSED FUNCTIONS

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
    */

     // self-destruct function 
     function destroyContract() public contractOwnerOnly {
        address payable receiver = payable(contractOwner);
         selfdestruct(receiver);
     }

     

}