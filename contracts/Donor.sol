// SPDX-License-Identifier: MIT
pragma solidity >=0.6.1;
import "./Recipient.sol";
import "./DonationMarket.sol";
import "./Token.sol";


contract Donor {

    struct donor {
        address owner;
        string username;
        string pw;
    }

    DonationMarket marketContract;
    Recipient recipientContract; 
    Token tokenContract;
    address contractOwner;

    uint256 public numDonors = 0;
    mapping(uint256 => donor) donors;
    mapping(uint256 => uint256[]) listingsCreated; // donorId => list of listingId that donor owns

    bool internal locked = false;
    bool internal contractStopped = true;

    constructor (DonationMarket marketAddress, Recipient recipientAddress, Token tokenAddress) public {
        marketContract = marketAddress;
        recipientContract = recipientAddress;
        tokenContract = tokenAddress;
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
            password
        );

        uint256 newDonorId = numDonors++;
        donors[newDonorId] = newDonor; //commit to state variable

        emit createdDonor(newDonorId);

        return newDonorId;  
    }

    event approved(uint256 listingId, address recipient);
    event createdDonor(uint256 donorId);
    event createdToken(uint256 donorId, uint256 listingId, uint256 amt);
    event approvedRecipientRequest(uint256 listingId, uint256 recipientId, uint256 donorId, uint256 requestId);
    event listingUnlisted(uint256 listingId);


    //modifier to ensure a function is callable only by its donor  
    modifier ownerOnly(uint256 donorId) {
        require(donors[donorId].owner == msg.sender, "You are not the donor!");
        _;
    }
    
    //modifier to ensure that the donor is valid
    modifier validDonorId(uint256 donorId) {
        require(donorId < numDonors, "Invalid donor Id");
        require(donors[donorId].owner == msg.sender, "You are not the donor!");
        _;
    }


    function createListing(uint256 donorId, uint256 amt, string memory category ) validDonorId(donorId) public {
        require(tokenContract.checkCredit() >= amt, "Donor does not have enough ether to create listing!");
        require(amt < 10 ether, "Donated amount hit limit! Donated amount cannot be more than 10 ether!");

        uint256 listingId = marketContract.createListing(donorId, amt, category);
        listingsCreated[donorId].push(listingId);
        tokenContract.transferToken(tx.origin, marketContract.getOwner(), amt);
        emit createdToken(donorId, listingId, amt);
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

    //Emergency Stop enabled in approve 
    function approveRecipientRequest(uint256 listingId, uint256 recipientId, uint256 donorId, uint256 requestId) validDonorId(donorId) stoppedInEmergency public {
        marketContract.approve(requestId, listingId);
        
        address donorAdd = donors[donorId].owner;
        recipientContract.completeRequest(requestId, listingId, donorAdd);
     
        emit approvedRecipientRequest(listingId, recipientId, donorId, requestId);
    }



    function getDonorAddress(uint256 donorId) public view returns (address) { // ownerOnly?
        return donors[donorId].owner;
    }
  
    function getActiveListings(uint256 donorId) public view returns (uint256[] memory) {
        require(listingsCreated[donorId].length > 0, "you do not have any listing");
        uint256[] memory activeListing =  new uint256[](listingsCreated[donorId].length);
        uint8 counter = 0;
        for (uint8 i=0; i < listingsCreated[donorId].length;  i++) {
            if (marketContract.checkListing(listingsCreated[donorId][i])) {
                activeListing[counter] =  listingsCreated[donorId][i];
                counter ++;
            }
        }
        return activeListing; 
    }


     // self-destruct function 
     function destroyContract() public contractOwnerOnly {
        address payable receiver = payable(contractOwner);
         selfdestruct(receiver);
     }

    

}