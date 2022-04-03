// SPDX-License-Identifier: MIT
pragma solidity >=0.6.1;
import "./Recipient.sol";
import "./DonationMarket.sol";
import "./Token.sol";
import "./DonorStorage.sol";


contract Donor {

    DonationMarket marketContract;
    Recipient recipientContract; 
    Token tokenContract;
    DonorStorage donorStorage;
    address contractOwner;

    bool internal locked = false;
    bool internal contractStopped = false;

    constructor (Token tokenAddress, DonationMarket marketAddress, Recipient recipientAddress, DonorStorage storageAddress) public {
        marketContract = marketAddress;
        recipientContract = recipientAddress;
        tokenContract = tokenAddress;
        donorStorage = storageAddress;
        contractOwner = msg.sender;
    }

    //function to create a new donor, and add to 'donors' map
    function createDonor (
        string memory name,
        string memory password
    ) public returns(uint256) {
        
        // create and add store donor in donorStorage
        uint256 newDonorId = donorStorage.createDonor(name, password, msg.sender);
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
        require(donorStorage.getOwner(donorId) == msg.sender, "You are not the donor!");
        _;
    }
    
    //modifier to ensure that the donor is valid
    modifier validDonorId(uint256 donorId) {
        require(donorId < donorStorage.getTotalOwners(), "donorId is not valid!");
        _;
    }


    function createListing(uint256 donorId, uint256 amt, string memory category ) validDonorId(donorId) public {
        require(tokenContract.checkCredit() >= amt, "Donor does not have enough ether to create listing!");
        require(amt < 10 ether, "Donated amount hit limit! Donated amount cannot be more than 10 ether!");

        uint256 listingId = marketContract.createListing(donorId, amt, category);
        donorStorage.addListingToDonor(donorId, listingId);
        tokenContract.transferToken(tx.origin, marketContract.getOwner(), amt);
        emit createdToken(donorId, listingId, amt);
    }

    modifier stoppedInEmergency {
        require(!contractStopped, "contract stopped!");
        _;
    }


    modifier contractOwnerOnly {
        require(msg.sender == contractOwner, "only the owner of the contract can call this method!");
        _;
    }

    function toggleContactStopped() public contractOwnerOnly {
        contractStopped = !contractStopped;
    }

    //Emergency Stop enabled in approve 
    function approveRecipientRequest(uint256 requestId, uint256 listingId, uint256 donorId, uint256 recipientId) validDonorId(donorId) stoppedInEmergency public {

        marketContract.approve(requestId, listingId);
        address donorAdd = donorStorage.getOwner(donorId);
        recipientContract.completeRequest(requestId, listingId, donorAdd);
     
        emit approvedRecipientRequest(listingId, recipientId, donorId, requestId);
    }


    function getActiveListings(uint256 donorId) public view returns (uint256[] memory) {
        uint8 counter = 0;
        uint256[] memory currentListings = donorStorage.getListings(donorId);
        uint256[] memory activeListing = new uint256[](currentListings.length);
        for (uint8 i=0; i < currentListings.length;  i++) {
            if (marketContract.checkListing(currentListings[i])) {
                activeListing[counter] = currentListings[i];
                counter ++;
            }
        }
        return activeListing; 
    }

    function getListings(uint256 donorId) public view returns (uint256[] memory) {
        uint256[] memory currentListings = donorStorage.getListings(donorId);
        return currentListings;
    }


     // self-destruct function 
     function destroyContract() public contractOwnerOnly {
        address payable receiver = payable(contractOwner);
         selfdestruct(receiver);
     }

    

}