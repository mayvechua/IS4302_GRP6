// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;
import "./Token.sol";

contract Recipient {

    enum recipientState {created, requesting, receivedDonation}

    struct recipient {
        recipientState state;
        address owner;
        string username;
        string pw;
        uint256 wallet; // amt of ether in wallet
        string category;
    }

    struct request {
        uint256 tokenId;
        uint256 amt;
        uint expireAt; // time from approved to expired 
    }

    Token tokenContract;
    address contractOwner;

    bool internal locked = false;
    bool public contractStopped = false;
    uint constant wait_period = 7 days;
    uint contract_maintenance; // time tracker, deprecate the withdrawToken() and check for expiration daily

    uint256 public numRecipients = 0;
    mapping(uint256 => recipient) public recipients;
    mapping(uint256 => request[]) public tokensRequested; // recipientId => request
    mapping(uint256 => request[]) public withdrawalTokens; // tokens to be withdrawn, available only for 7 days

    
    constructor (Token tokenAddress) public {
        tokenContract = tokenAddress;
        contractOwner = msg.sender;
        autoDeprecate(); // set daily contract check
    }

    //function to create a new recipient, and add to 'recipients' map
    function createRecipient (
        string memory name,
        string memory password,
        string memory category
    ) public returns(uint256) {
        
        recipient memory newRecipient = recipient(
            recipientState.created,
            msg.sender, // recipient address
            name,
            password,
            0, // wallet
            category
        );
        
        uint256 newRecipientId = numRecipients++;
        recipients[newRecipientId] = newRecipient; 
        return newRecipientId;   
    }

    event requestedDonation(uint256 recipientId, uint256 tokenId, uint256 amt, uint256 deadline);
    event completedToken(uint256 recipientId, uint256 tokenId);

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
    function transferPayment(address payable token, uint256 amt) noReEntrant public payable {
        token.transfer(amt);
    }

    function refundToken() public whenDeprecated {
        for (uint recId; recId < numRecipients; recId++) {
            for (uint token; token < withdrawalTokens[recId].length; token++) {
                if (block.timestamp > withdrawalTokens[recId][token].expireAt) {
                    uint256 amt = withdrawalTokens[recId][token].amt;
                    address payable addr = payable(tokenContract.getOwner());

                    recipients[recId].wallet -= amt; // deduct the expired tokens from the recipient's wallet

                    transferPayment(addr, amt); // refund the expired tokens to the owner

                    locked = false;

                    delete withdrawalTokens[recId][token]; 
                }
            }
        }

        autoDeprecate(); // reset the daily auto deprecation time
        
    }
    
    function withdrawTokens(uint256 recipientId) public ownerOnly(recipientId) validRecipientId(recipientId) stoppedInEmergency isActive {
        // TODO: implement automatic depreciation of each token (7days to cash out for reach approval)! 

        require(recipients[recipientId].wallet > 0, "Invalid amount to be withdrawn from wallet!");
        uint256 tokenAmt = recipients[recipientId].wallet;

        address payable receiving = payable(getRecipientAddress(recipientId));
        recipients[recipientId].wallet = 0;

        delete withdrawalTokens[recipientId]; // all tokens withdrawn

        transferPayment(receiving, tokenAmt);

        // unlock after the transaction is completed
        locked = false;
    }

    function requestDonation(uint256 recipientId, uint256 tokenId, uint256 requestedAmt, uint256 deadline) public ownerOnly(recipientId) validRecipientId(recipientId) {
        require(requestedAmt > 0 ether, "minimum request need to contain at least 1 eth");
        require(requestedAmt < 10 ether, "Requested Amounted hit limit");
        require (keccak256(abi.encode(tokenContract.getCategory(tokenId))) == keccak256(abi.encode(recipients[recipientId].category)),  
        "you are not eligible to request for this token");
            request[] memory requests= tokensRequested[recipientId];
            for (uint8 i; i< requests.length; i++) {
                require(requests[i].tokenId == tokenId, "You have already request for this token!"); 
            }
        tokenContract.addRequest(tokenId, recipientId, requestedAmt,deadline);
        tokensRequested[recipientId].push(request(tokenId,requestedAmt, block.timestamp));


        recipients[recipientId].state = recipientState.requesting;

        emit requestedDonation(recipientId, tokenId, requestedAmt, deadline);
    }

    function completeToken(uint256 recipientId,uint256 tokenId) public {
        bool isIndex = false;
    
        //store the token in database
        for (uint8 i; i< tokensRequested[recipientId].length; i++) {
            if (tokensRequested[recipientId][i].tokenId == tokenId) {
                isIndex = true;
                recipients[recipientId].wallet += tokensRequested[recipientId][i].amt;

                tokensRequested[recipientId][i].expireAt = block.timestamp + wait_period;

                withdrawalTokens[recipientId].push(tokensRequested[recipientId][i]); 
            }
            if (isIndex) {
                tokensRequested[recipientId][i] = tokensRequested[recipientId][i+1];
            }
        }

        tokensRequested[recipientId].pop();

        recipients[recipientId].state = recipientState.receivedDonation;

        emit completedToken(recipientId, tokenId);
    }

    function getWallet(uint256 recipientId) public view ownerOnly(recipientId) validRecipientId(recipientId) returns (uint256) {
        return recipients[recipientId].wallet;
    }

    function getRecipientAddress(uint256 recipientId) public view validRecipientId(recipientId) returns (address) {
        return recipients[recipientId].owner;
    }

     // self-destruct function 
     function destroyContract() public contractOwnerOnly {
        address payable receiver = payable(contractOwner);
         selfdestruct(receiver);
     }

     

}