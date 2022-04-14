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

    constructor(
        Token tokenAddress,
        DonationMarket marketAddress,
        Recipient recipientAddress,
        DonorStorage storageAddress
    ) public {
        marketContract = marketAddress;
        recipientContract = recipientAddress;
        tokenContract = tokenAddress;
        donorStorage = storageAddress; //Data storage for this contract
        contractOwner = msg.sender;
    }


    //Access Restriction Functions
    //modifier to ensure a function is callable only by its donor
    modifier ownerOnly(uint256 donorId) {
        require(
            donorStorage.getOwner(donorId) == msg.sender,
            "You are not the donor!"
        );
        _;
    }

    //modifier to ensure that the donor is valid
    modifier validDonorId(uint256 donorId) {
        require(
            donorId < donorStorage.getTotalOwners(),
            "donorId is not valid!"
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

    //Security Functions 
    // self-destruct function
    function destroyContract() public contractOwnerOnly {
        address payable receiver = payable(contractOwner);
        selfdestruct(receiver);
    }

    //Emergency Stop Functions
    function toggleContactStopped() public contractOwnerOnly {
        contractStopped = !contractStopped;
    }
    //Events 
    event approved(uint256 listingId, address recipient);
    event createdDonor(uint256 donorId);
    event createdListing(uint256 donorId, uint256 listingId, uint256 amt);
    event approvedRecipientRequest(
        uint256 listingId,
        uint256 recipientId,
        uint256 donorId,
        uint256 requestId
    );
    event listingUnlisted(uint256 listingId);

    //Core Functions 
    // Create a Listing that would be listed in the Donation Market 
    function createListing(
        uint256 donorId,
        uint256 amt,
        string memory category
    ) public validDonorId(donorId) {
        require(
            tokenContract.checkCredit() >= amt,
            "Donor does not have enough ether to create listing!"
        );
        uint256 listingId = marketContract.createListing(
            donorId,
            amt,
            category
        );
        donorStorage.addListingToDonor(donorId, listingId);
        tokenContract.transferToken(tx.origin, marketContract.getOwner(), amt);
        emit createdListing(donorId, listingId, amt);
    }


    //function to create a new donor, and add to 'donors' map
    function createDonor(string memory name)
        public
        returns (uint256)
    {
        // create and add store donor in donorStorage
        uint256 newDonorId = donorStorage.createDonor(name);
        emit createdDonor(newDonorId);
        return newDonorId;
    }
    //Approve Request Function to release tokens to recipeint based on their request 
    // Emergency Stop enabled for security purpose since this function include transferring of tokens
    function approveRecipientRequest(
        uint256 requestId,
        uint256 listingId,
        uint256 donorId,
        uint256 recipientId
    ) public ownerOnly(donorId) validDonorId(donorId) stoppedInEmergency {
        marketContract.approve(requestId, listingId);
        address donorAdd = donorStorage.getOwner(donorId);
        recipientContract.completeRequest(requestId, listingId, donorAdd);

        emit approvedRecipientRequest(
            listingId,
            recipientId,
            donorId,
            requestId
        );
    }
    //Unlist Donor Listing 
    function unlist(uint256 donorId, uint256 listingId) public ownerOnly(donorId) validDonorId(donorId){
        marketContract.unlist(listingId);
        donorStorage.removeListing(donorId);
    }
    //Getter Functions 
    // Get all active (still listed in market) listing of donors to be shown in Frontend 
    function getActiveListings(uint256 donorId)
        public   ownerOnly(donorId) validDonorId(donorId)
        view 
        returns (uint256[] memory)
    {
        uint8 counter = 0;
        uint256[] memory allListings = donorStorage.getListings(donorId);
        uint256[] memory activeListing = new uint256[](donorStorage.getNumActiveListing(donorId));
        for (uint8 i = 0; i < allListings.length; i++) {
            if (marketContract.checkListing(allListings[i])) {
                activeListing[counter] = allListings[i];
                counter++;
            }
        }
        return activeListing;
    }  

}
