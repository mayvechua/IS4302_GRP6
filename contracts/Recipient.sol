// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

contract Recipient {

    enum recipientState {created, requesting, receivedDonation }

    struct recipient {
        recipientState state;
        address owner;
        string username;
        string pw;
        uint256 etherWallet; // amt of ether in wallet
        uint256 tokenWallet;
    }

    struct tokenState {
        uint256 tokenId;
        uint256 approved; // 1: approved, 0: not approved
        uint256 received; // amt received after the token is completed
    }

    uint256 public numRecipients = 0;
    mapping(uint256 => recipient) public recipients;
    mapping(uint256 => tokenState[]) public tokensRequested; // recipientId => tokenState
    mapping(uint256 => tokenState[]) public tokensApproved;
    mapping(uint256 => tokenState[]) public tokensNotApproved;
    

    //function to create a new recipient, and add to 'recipients' map
    function createRecipient (
        string memory name,
        string memory password
    ) public returns(uint256) {
        
        recipient memory newRecipient = recipient(
            recipientState.created,
            msg.sender, // recipient address
            name,
            password,
            0, // ether wallet
            0 // token wallet
        );
        
        uint256 newRecipientId = numRecipients++;
        recipients[newRecipientId] = newRecipient; //commit to state variable
        return newRecipientId;   //return new diceId
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

    function convertTokens(uint256 recipientId) public ownerOnly(recipientId) validRecipientId(recipientId) {
        // implement wait 7 days before converting tokens to ether
        require(recipients[recipientId].tokenWallet > 0, "Invalid tokens input to be converted to ether in the wallet!");
        uint256 tokenAmt = recipients[recipientId].tokenWallet;

        recipients[recipientId].etherWallet += tokenAmt;
        recipients[recipientId].tokenWallet = 0;

    }

    function requestDonation(uint256 recipientId, uint256 tokenId, uint256 requestedAmt) public ownerOnly(recipientId) validRecipientId(recipientId) {
        tokenState memory newToken = tokenState(
            tokenId,
            0, // token not approved
            requestedAmt // amount requested from token
        );

        tokensRequested[recipientId].push(newToken);
        tokensNotApproved[recipientId].push(newToken);

    }

    function approvedToken(uint256 tokenId, uint256 recipientId, uint256 amt) validRecipientId(recipientId) public payable {
        uint256 len = tokensRequested[recipientId].length;
        for (uint i = 0; i< len; i++) {
            if (tokensRequested[recipientId][i].tokenId == tokenId) {
                tokensRequested[recipientId][i].approved = 1;
                tokensRequested[recipientId][i].received -= amt; // subtract the remainder balance that is not donated
                
                tokensApproved[recipientId].push(tokensRequested[recipientId][i]); // add to tokensCompleted
                
                for (uint z = 0; z < tokensNotApproved[recipientId].length; z++) { // remove from tokensIncomplete
                    if (tokensNotApproved[recipientId][z].tokenId == tokenId) {
                        delete tokensNotApproved[recipientId][z];
                    }
                }
                break;
            }
        }

        address payable _owner = payable(recipients[recipientId].owner);
        _owner.transfer(amt); // transfer back the remaining ether that is not donated to the recipient
    }

    function getWallet(uint256 recipientId) public view ownerOnly(recipientId) validRecipientId(recipientId) returns (uint256) {
        return recipients[recipientId].etherWallet;
    }

    function getRecipientAddress(uint256 recipientId) public view validRecipientId(recipientId) returns (address) {
        return recipients[recipientId].owner;
    }

    


}