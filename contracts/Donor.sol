// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;
import "./Token.sol";
import "./Recipient.sol";

contract Donor {

    struct donor {
        address owner;
        string username;
        string pw;
        uint256 walletValue; // amt of ether in wallet
    }

    Token tokenContract;
    Recipient recipientContract;
    address contractOwner;

    uint256 public numDonors = 0;
    mapping(uint256 => donor) public donors;
    mapping(uint256 => uint256[]) public tokensCreated; // donorId => list of tokenID that donor owns

    bool internal locked = false;
    bool public contractStopped = false;

    constructor (Token tokenAddress, Recipient recipientAddress) public {
        tokenContract = tokenAddress;
        recipientContract = recipientAddress;
        contractOwner = msg.sender;
    }

    //function to create a new donor, and add to 'donors' map
    function createDonor (
        string memory name,
        string memory password
    ) public returns(uint256) {
        
        donor memory newDonor = donor(
            msg.sender, // donor address
            name,
            password,
            0
        );

        uint256 newDonorId = numDonors++;
        donors[newDonorId] = newDonor; //commit to state variable

        emit createdDonor(newDonorId);

        return newDonorId;  
    }

    event toppedUpWallet(uint256 donorId, uint256 amt);
    event approved(uint256 tokenID, address recipient);
    event createdDonor(uint256 donorId);
    event createdToken(uint256 donorId, uint256 tokenId, uint256 amt);
    event approvedRecipient(uint256 tokenId, uint256 recipientId, uint256 donorId);



    //modifier to ensure a function is callable only by its donor  
    modifier ownerOnly(uint256 donorId) {
        require(donors[donorId].owner == msg.sender, "You are not the donor!");
        _;
    }
    
    //modifier to ensure that the donor is valid
    modifier validDonorId(uint256 donorId) {
        require(donorId < numDonors);
        _;
    }

    // mutex: prevent re-entrant
    modifier noReEntrant {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    function createToken(uint256 donorId, uint256 amt, string memory category ) validDonorId(donorId) public {
        require(getWallet(donorId) >= amt, "Donor does not have enough ether to create token!");
        require(amt < 10 ether, "Donated amount hit limit! Donated amount cannot be more than 10 ether!");
        donors[donorId].walletValue -= amt; 

        uint256 tokenId = tokenContract.createToken(donorId, amt, category);
        tokensCreated[donorId].push(tokenId);

        //reset locked to allow for payment for new token creation
        locked = false;

        emit createdToken(donorId, tokenId, amt);
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

    //Emergency Stop enabled in approve 
    function approveRecipient(uint256 tokenId, uint256 recipientId, uint256 donorId) validDonorId(donorId) stoppedInEmergency public payable {
        uint256 tokenIsUnlisted = tokenContract.approve(recipientId, tokenId);
        recipientContract.completeToken(recipientId, tokenId);
        if (tokenIsUnlisted == 2) {   
            bool isIndex = false;
            for (uint8 i; i< tokensCreated[donorId].length; i++) {
                if (tokensCreated[donorId][i] == tokenId) {
                    isIndex = true;
                }
                if (isIndex) {
                    tokensCreated[donorId][i] = tokensCreated[donorId][i+1];
                }
            }

             tokensCreated[donorId].pop();
        }
        //TODO: store completed tokens in historical database? do we need to as transaction are all recorded in block?

        emit approvedRecipient(tokenId, recipientId, donorId);
    }

    function transferToContract(uint256 amt) public payable noReEntrant {
        require(amt > 0, "cannot transfer 0 ether to contract owner!");
        address payable addr = payable(contractOwner);
        
        addr.transfer(amt); 
    }

    function topUpWallet(uint256 donorId) ownerOnly(donorId) validDonorId(donorId) public payable {
        require(msg.value <= 10 ether, "The top-up value is more than the wallet limit!"); // limit the amount of ether stored in the wallet
        require(msg.value > 0, "The top-up value cannot be 0!");
        donors[donorId].walletValue += msg.value;

        transferToContract(msg.value);  // transfer the ether to the contractOwner
        locked = false;

        emit toppedUpWallet(donorId, msg.value);
    }

    function getWallet(uint256 donorId) ownerOnly(donorId) validDonorId(donorId) public view returns(uint256) {
        return donors[donorId].walletValue;
    } 

    function getDonorAddress(uint256 donorId) public view returns (address) { // ownerOnly?
        return donors[donorId].owner;
    }

    function getActiveTokens(uint256 donorId) public view returns (uint256[] memory) {
        return tokensCreated[donorId]; // tokens active now, if want see historical tokens --> view in database 
    }


     // self-destruct function 
     function destroyContract() public contractOwnerOnly {
        address payable receiver = payable(contractOwner);
         selfdestruct(receiver);
     }

    

}