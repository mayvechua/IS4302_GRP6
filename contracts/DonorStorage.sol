pragma solidity >=0.6.1;

contract DonorStorage {

    struct donor {
        address owner;
        string username;
        string pw;
    }

    address owner;
    uint256 public numDonors = 0;
    mapping(uint256 => donor) public donors;

    function storeDonor (
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
        return newDonorId;
    }

    function getOwner (uint256 donorId) public view returns(address) {
        return donors[donorId].owner;
    }

    function getTotalOwners () public view returns(uint256) {
        return numDonors;
    }

}