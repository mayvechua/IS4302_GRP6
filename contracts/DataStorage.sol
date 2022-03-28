// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;
pragma experimental ABIEncoderV2;

contract DataStorage {
    struct donation {
        uint256 id;
        uint256 amt;
        address recipient;
        string category;
        uint256 timestamp; // can call block.timestamp when donation is made and store it
    }

    struct request {
        uint256 id;
        uint256 amt;
        address requester;
        string category;
        uint256 timestamp; // time request was made
        uint256 deadline;
    }

    mapping(address => donation[]) donationHistory;
    mapping(address => request[]) requestHistory;
    request[] listings;
    address owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier ownerOnly {
        require(msg.sender == owner);
        _;
    }

    bool internal locked;
    bool isStopped = false;

    modifier noReentrancy() {
        require(!locked, "No re-entrancy");
        _;
    }

    modifier stoppedInEmergency {
        require(!isStopped);
        _;
    }

    //Security functions
    //Emergency Stop
    function stopContract() public ownerOnly() {
        isStopped = true;
    }

    function resumeContract() public ownerOnly()  {
        isStopped = false;
    }

    //Mortal
    function selfDestruct() public ownerOnly() {
        address payable addr = payable(owner);
        selfdestruct(addr); 
    }

    //Setter functions
    function setDonation(uint256 id, uint256 amt, address recipient, string memory category, uint256 timestamp) public stoppedInEmergency returns(donation memory) {
        return donation(id, amt, recipient, category, timestamp);
    }

    function addDonationHistory(donation memory transaction) public stoppedInEmergency {
        donationHistory[msg.sender].push(transaction);
    }

    function setRequest(uint256 id, uint256 amt, address requester, string memory category, uint256 timestamp, uint256 deadline) public stoppedInEmergency returns(request memory) {
        return request(id, amt, requester, category, timestamp, deadline);
    }

    function addRequestHistory(request memory transaction) public stoppedInEmergency {
        requestHistory[msg.sender].push(transaction);
    }

    //Getter functions
    function getDonationHistory() public view returns(donation[] memory){
        return donationHistory[msg.sender];
    }

    function getRequestHistory() public view returns(request[] memory){
        return requestHistory[msg.sender];
    }

    function getListings() public view returns(request[] memory) {
        return listings;
    }

    function getOwner() public view returns(address) {
        return owner;
    }
}