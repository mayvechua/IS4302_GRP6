// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;
import './Token.sol';

contract Recipient {

    enum recipientState {created, requesting, receivedDonation }

    struct recipient {
        recipientState state;
        address owner;
        string username;
        string pw;
        uint256 etherWallet; // amt of ether in wallet
        uint256 tokenWallet;
        uint8 category;
    }
    struct request {
        uint256 tokenId;
        uint256 amt;
    }
    Token tokenContract;


    uint256 public numRecipients = 0;
    mapping(uint256 => recipient) public recipients;
    mapping(uint256 => request[]) public tokensRequested; // recipientId => tokenState
    // mapping(uint256 => tokenState[]) public tokensApproved;
    // mapping(uint256 => tokenState[]) public tokensNotApproved;
    
   constructor (Token tokenAddress) public {
        tokenContract = tokenAddress;
    }

    //function to create a new recipient, and add to 'recipients' map
    function createRecipient (
        string memory name,
        string memory password,
        uint8 category
    ) public returns(uint256) {
        
        recipient memory newRecipient = recipient(
            recipientState.created,
            msg.sender, // recipient address
            name,
            password,
            0, // ether wallet
            0, // token wallet
            category
        );
        
        uint256 newRecipientId = numRecipients++;
        recipients[newRecipientId] = newRecipient; 
        return newRecipientId;   
    }

    //modifier to ensure a function is callable only by its owner    
    modifier ownerOnly(uint256 recipientId) {
        require(recipients[recipientId].owner == msg.sender);
        _;
    }
    
    modifier validRecipientId(uint256 recipientId) {
        require(recipientId < numRecipients);
        _;
    }
    //TODO: revisit the logic
    //TODO: add mutex
    //ToDO:  emergency stop in approve
    function convertTokens(uint256 recipientId) public ownerOnly(recipientId) validRecipientId(recipientId) {
        // TODO: implement automatic depreciation of each token (7days to cash out for reach approval)! 
        require(recipients[recipientId].tokenWallet > 0, "Invalid tokens input to be converted to ether in the wallet!");
        uint256 tokenAmt = recipients[recipientId].tokenWallet;

        recipients[recipientId].etherWallet += tokenAmt;
        recipients[recipientId].tokenWallet = 0;

    }

    function requestDonation(uint256 recipientId, uint256 tokenId, uint256 requestedAmt, uint256 deadline) public ownerOnly(recipientId) validRecipientId(recipientId) {
        require(requestedAmt > 0 , "minimum request need to contain at least 1 eth");
        require(requestedAmt <50 , "Requested Amounted hit limit");
        require (tokenContract.getCategory(tokenId) == recipients[recipientId].category,  
        "you are not eligible to request for this token");
            request[] memory reqeusts= tokensRequested[recipientId];
            for (uint8 i; i< reqeusts.length; i++) {
                require(reqeusts[i].tokenId == tokenId, "You have already request for this token!"); 
            }
        tokenContract.addRequest(tokenId, recipientId, requestedAmt,deadline, recipients[recipientId].owner);
        tokensRequested[recipientId].push(request(tokenId,requestedAmt));

    }

    function completeToken(uint256 recipientID,uint256 tokenId) public {
            bool isIndex = false;
        
            //store the token in database
            for (uint8 i; i< tokensRequested[recipientID].length; i++) {
                if (tokensRequested[recipientID][i].tokenId == tokenId) {
                    isIndex = true;
                    recipients[recipientID].etherWallet += tokensRequested[recipientID][i].amt;
                }
                if (isIndex) {
                    tokensRequested[recipientID][i] = tokensRequested[recipientID][i+1];
                }
            }

            tokensRequested[recipientID].pop();
    
        
    }
    function getWallet(uint256 recipientId) public view ownerOnly(recipientId) validRecipientId(recipientId) returns (uint256) {
        return recipients[recipientId].etherWallet;
    }

    function getRecipientAddress(uint256 recipientId) public view validRecipientId(recipientId) returns (address) {
        return recipients[recipientId].owner;
    }
     //TODO: add selfdestruct function 



    


}