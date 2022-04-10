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
    uint256 constant wait_period = 7 days;
    uint256 contract_maintenance; // time tracker, deprecate the withdrawToken() and check for expiration daily

    constructor(
        Token tokenAddress,
        DonationMarket marketAddress,
        RecipientStorage storageAddress
    ) public {
        tokenContract = tokenAddress;
        marketContract = marketAddress;
        recipientStorage = storageAddress;
        contractOwner = msg.sender;
        autoDeprecate(); // set daily contract check
    }
    //Access Restriction 
     //modifier to ensure a function is callable only by its owner
    modifier ownerOnly(uint256 recipientId) {
        require(
            recipientStorage.getRecipientOwner(recipientId) == msg.sender,
            "you are not the recipient!"
        );
        _;
    }

    modifier stoppedInEmergency() {
        require(!contractStopped, "contract stopped!");
        _;
    }

    modifier contractOwnerOnly() {
        require(
            msg.sender == contractOwner,
            "only the owner of the contract can call this method!"
        );
        _;
    }

    modifier validRecipientId(uint256 recipientId) {
        require(
            recipientId <= recipientStorage.getTotalRecipients(),
            "recipientId does not exist"
        );
        _;
    }

    modifier isActive() {
        require(!hasExpired(), "Not active!");
        _;
    }

    modifier whenDeprecated() {
        require(hasExpired(), "has not expired!");
        _;
    }

    // mutex: prevent re-entrant
    modifier noReEntrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }    
    //Events
    event requestedDonation(
        uint256 recipientId,
        uint256 listingId,
        uint256 amt,
        uint256 deadline,
        uint256 requestId
    );
    event completedRequest(uint256 requestId, uint256 listingId);
    event requestCreated(uint256 requestId);
    event enteredRequest(bool entered);
    event addingToMarket(uint8 deadline, uint256 amount);
   //Security Functions 

    function toggleContactStopped() public contractOwnerOnly {
        contractStopped = !contractStopped;
    }

    // deprecate daily to check if the token has expired before allowing withdrawal of tokens
    function autoDeprecate() public {
        contract_maintenance = block.timestamp + 1 days;
    }

    function hasExpired() public view returns (bool) {
        return block.timestamp > contract_maintenance ? true : false;
    }
    // self-destruct function
    function destroyContract() public contractOwnerOnly {
        address payable receiver = payable(contractOwner);
        selfdestruct(receiver);
    }



    //Core Functions 
    //function to create a new recipient, and add to 'recipients' map

    // separate the payment to check for re-entrant
    //Functions are private so that it can only be used internally and not even by derived contracts
    function transferPayment(
        address sender,
        address receiver,
        uint256 token
    ) private noReEntrant {
        tokenContract.transferToken(sender, receiver, token);
    }

    function cashOutTokens(uint256 amt) private noReEntrant {
        tokenContract.cashOut(amt);
    }

    //Functions that will refund tokens if the approved request expired 
    //Expired meaning donor approve request, requested tokens are transfered to recipient but recipient did not cash out within 7 days)
    function refundToken() public whenDeprecated {
        for (
            uint256 recId;
            recId < recipientStorage.getTotalRecipients();
            recId++
        ) {
            uint256[] memory withdrawals = recipientStorage
                .getRecipientWithdrawals(recId);
            for (uint256 req; req < withdrawals.length; req++) {
                uint256 withdrawalId = withdrawals[req];
                if (
                    block.timestamp >
                    recipientStorage.getWithdrawalRecipient(withdrawalId)
                ) {
                    uint256 amt = recipientStorage.getWithdrawalAmount(
                        withdrawalId
                    );
                    recipientStorage.modifyRecipientWallet(
                        recipientStorage.getWithdrawalRecipient(withdrawalId),
                        amt,
                        "-"
                    ); // deduct the expired tokens from the recipient's wallet
                    transferPayment(
                        recipientStorage.getRecipientOwner(recId),
                        recipientStorage.getWithdrawalDonor(withdrawalId),
                        amt
                    ); // return the expired tokens to the donor of the tokens (currently is marketcontract first)

                    locked = false;

                    recipientStorage.removeWithdrawal(withdrawalId);
                }
            }
        }

        autoDeprecate(); // reset the daily auto deprecation time
    }
    
    // allow recipient to withdraw tokens
    function withdrawTokens(uint256 recipientId)
        public
        ownerOnly(recipientId)
        validRecipientId(recipientId)
        stoppedInEmergency
    {
        recipientStorage.removeWithdrawal(recipientId);
        cashOutTokens(recipientStorage.emptyRecipientWallet(recipientId));
        // unlock after the transaction is completed
        locked = false;
    }


    //when developer (oracle) approve of the proof of usage, it will be tagged to a request to prevent duplicative usage of proof of usage
    function createRequest(
        uint256 recipientId,
        uint256 requestedAmt,
        uint8 deadline,
        string memory category
    ) public returns (uint256) {
        require(
            msg.sender == contractOwner,
            "you are not allowed to use this function"
        );
        uint256 requestId = recipientStorage.createRequest(
            recipientId,
            requestedAmt,
            deadline,
            category
        );
        emit requestCreated(requestId);
        return requestId;
    }
    
    //functions to create recipient 
    function createRecipient(string memory name, string memory password)
        public
        returns (uint256)
    {
        uint256 newRecipientId = recipientStorage.createRecipient(
            name,
            password
        );
        return newRecipientId;
    }

    // allow recipeint to use their approved requestID to request for listing in donationMarket
    function requestDonation(
        uint256 recipientId,
        uint256 listingId,
        uint256 requestId
    ) public ownerOnly(recipientId) validRecipientId(recipientId) {
        //checks
        require(
            keccak256(abi.encode(marketContract.getCategory(listingId))) ==
                keccak256(
                    abi.encode(recipientStorage.getRequestCategory(requestId))
                ),
            "you are not eligible to request for this listing"
        );
        require(
            !recipientStorage.verifyRequestListing(requestId, listingId),
            "You have already requested for this listing"
        );
        emit enteredRequest(true);

        uint8 deadline = recipientStorage.getRequestDeadline(requestId);
        uint256 amount = recipientStorage.getRequestAmount(requestId);

        emit addingToMarket(deadline, amount);

        marketContract.addRequest(
            listingId,
            recipientId,
            amount,
            deadline,
            requestId
        );
        recipientStorage.addListingToRequest(requestId, listingId);
        // recipients[recipientId].state = recipientState.requesting;
        emit requestedDonation(
            recipientId,
            listingId,
            amount,
            deadline,
            requestId
        );
    }

    // Request is completed meaning donor approved request and transfer requested tokens to recipient 
    function completeRequest(
        uint256 requestId,
        uint256 listingId,
        address donorAddress
    ) public {
        recipientStorage.createWithdrawal(requestId); // add withdrawal
        uint256 withdrawalId = requestId;
        recipientStorage.addWithdrawalExpiry(
            withdrawalId,
            block.timestamp + wait_period
        ); // withdrawal of tokens allowed for 7 days from time of completion

        // get recipient of withdrawal
        uint256 recipientId = recipientStorage.getWithdrawalRecipient(
            withdrawalId
        );
        // facilitate withdrawal
        uint256 amount = recipientStorage.getWithdrawalAmount(withdrawalId);
        recipientStorage.modifyRecipientWallet(recipientId, amount, "+");
        recipientStorage.addWithdrawalRefundAddress(withdrawalId, donorAddress);
        // remove request
        recipientStorage.removeRequest(requestId);

        emit completedRequest(requestId, listingId);
    }

    //GETTER FUNCTIONS
    //getter functions to help recipients keep track of their active request in Frontend
    function getRecipientRequest(uint256 recipientId)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory activeRequest = new uint256[](
            recipientStorage.getRequests(recipientId).length
        );
        uint8 counter = 0;
        for (
            uint8 i = 0;
            i < recipientStorage.getRequests(recipientId).length;
            i++
        ) {
            if (
                recipientStorage.checkRequestValidity(
                    recipientStorage.getRequests(recipientId)[i]
                )
            ) {
                activeRequest[counter] = recipientStorage.getRequests(
                    recipientId
                )[i];
                counter++;
            }
        }
        return activeRequest;
    }


}
