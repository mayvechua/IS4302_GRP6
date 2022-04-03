// SPDX-License-Identifier: MIT
pragma solidity >=0.6.1;

contract DonorStorage {

    struct donor {
        address owner;
        string username;
        string pw;
        uint256[] listings;
    }

    address owner = msg.sender; // set deployer as owner of storage
    uint256 public numDonors = 0; // total number of donors
    mapping(uint256 => donor) public donors; // donors

    // stores new donor into mapping
    function createDonor (
        string memory name,
        string memory password,
        address sender
    ) public returns(uint256) {
        uint256[] memory initListingsArray;
        donor memory newDonor = donor(
                tx.origin, // donor address
                name,
                password,
                initListingsArray
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
    }

    // get collection of listings for donor 
    function getListings (uint256 donorId) public view returns(uint256[] memory) {
        return donors[donorId].listings;
    }

}