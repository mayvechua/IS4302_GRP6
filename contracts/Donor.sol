// SPDX-License-Identifier: MIT
pragma solidity >=0.6.1;
import "./Listing.sol";
import "./Recipient.sol";

contract Donor {

    struct donor {
        address owner;
        string username;
        string pw;
        uint256 walletValue; // amt of ether in wallet
    }

    Listing listingContract;
    Recipient recipientContract;
    address contractOwner;

    uint256 public numDonors = 0;
    mapping(uint256 => donor) public donors;
    mapping(uint256 => uint256[]) public listingsCreated; // donorId => list of listingId that donor owns

    bool internal locked = false;
    bool public contractStopped = false;

    constructor (Listing listingAddress, Recipient recipientAddress) public {
        listingContract = listingAddress;
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
    event approved(uint256 listingId, address recipient);
    event createdDonor(uint256 donorId);
    event createdToken(uint256 donorId, uint256 listingId, uint256 amt);
    event approvedRecipientRequest(uint256 listingId, uint256 recipientId, uint256 donorId, uint256 requestId);



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

    function transferPayment(address payable listing, uint256 amt) noReEntrant public payable {
         listing.transfer(amt);
     }

    function createToken(uint256 donorId, uint256 amt, string memory category ) validDonorId(donorId) public {
        require(getWallet(donorId) >= amt, "Donor does not have enough ether to create listing!");
        require(amt < 10 ether, "Donated amount hit limit! Donated amount cannot be more than 10 ether!");
        donors[donorId].walletValue -= amt; 

        address payable listing = payable(listingContract.getOwner());

          // add mutex
         transferPayment(listing, amt);

        uint256 listingId = listingContract.createToken(donorId, amt, category);
        listingsCreated[donorId].push(listingId);

        //reset locked to allow for payment for new listing creation
        locked = false;

        emit createdToken(donorId, listingId, amt);
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
    function approveRecipientRequest(uint256 listingId, uint256 recipientId, uint256 donorId, uint256 requestId) validDonorId(donorId) stoppedInEmergency public payable {
        uint256 listingIsUnlisted = listingContract.approve(recipientId, requestId, listingId);
        recipientContract.completeRequest(recipientId, requestId, listingId);
        if (listingIsUnlisted == 2) {   
            bool isIndex = false;
            for (uint8 i; i< listingsCreated[donorId].length; i++) {
                if (listingsCreated[donorId][i] == listingId) {
                    isIndex = true;
                }
                if (isIndex) {
                    listingsCreated[donorId][i] = listingsCreated[donorId][i+1];
                }
            }

             listingsCreated[donorId].pop();
        }

        emit approvedRecipientRequest(listingId, recipientId, donorId, requestId);
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

    function getActiveListings(uint256 donorId) public view returns (uint256[] memory) {
        return listingsCreated[donorId]; // listings active now, if want see historical listings --> view in database 
    }


     // self-destruct function 
     function destroyContract() public contractOwnerOnly {
        address payable receiver = payable(contractOwner);
         selfdestruct(receiver);
     }

    

}