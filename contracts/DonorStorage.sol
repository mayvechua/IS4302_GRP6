// SPDX-License-Identifier: MIT
pragma solidity >=0.6.1;

contract DonorStorage {

    struct donor {
        address owner;
        string username;
        uint256[] listings;
        uint256 numActiveListing; 
    }

    address owner = msg.sender; // set deployer as owner of storage
    uint256  numDonors = 0; // total number of donors
    mapping(uint256 => donor) donors; // donors
    //Access Restriction 
    modifier contractOwnerOnly() {
        require(
            msg.sender == owner,
            "you are not allowed to use this function"
        );
        _;
    }
    
    //Security Functions
    
    //Self-destruct function
    bool public locked = false;
    function destroyContract() public contractOwnerOnly {
        address payable receiver = payable(owner);
        selfdestruct(receiver);
    }
    // stores new donor into mapping
    function createDonor (
        string memory name
    ) public returns(uint256) {
        uint256[] memory initListingsArray;
        donor memory newDonor = donor(
                tx.origin, // donor address
                name,
                initListingsArray, 0
            );
            uint256 newDonorId = numDonors++;
            donors[newDonorId] = newDonor; //commit to state variable
        return newDonorId;
    }

    // returns address/owner of donor 
    function getOwner (uint256 donorId) public view returns(address) {
        return donors[donorId].owner;
    }

    // get total amount of owners
    function getTotalOwners () public view returns(uint256) {
        return numDonors;
    }

    // add new listingid to corresponding donor
    function addListingToDonor (uint256 donorId, uint256 listingId) public {
        donors[donorId].listings.push(listingId);
        donors[donorId].numActiveListing+=1;
    }

    //remove number of active listing to corresponding donor
    function removeListing(uint256 donorId) public {
        donors[donorId].numActiveListing -=1;
    }

    //get number of active listing 
    function getNumActiveListing(uint256 donorId) public view returns (uint256) {
        return donors[donorId].numActiveListing;
    }
    // get collection of listings for donor 
    function getListings(uint256 donorId) public view returns(uint256[] memory) {
        return donors[donorId].listings;
    }

}