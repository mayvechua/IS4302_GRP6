// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import "./ERC20.sol";

contract Token {
    ERC20 erc20Contract;
    uint256 supplyLimit; // have a supply limit to cap the amount of ether that can be stored in this contract 
    address owner;
    uint256 conversionRate;

    //Access Restriction
    // mutex: prevent re-entrant
    modifier noReEntrant() {
        require(!locked, "No re-entrancy");
        _;
    }

    modifier stoppedInEmergency() {
        require(!contractStopped);
        _;
    }

    modifier contractOwnerOnly() {
        require(
            msg.sender == owner,
            "you are not allowed to use this function"
        );
        _;
    }
    
    //Security Functions
    
    //Self-destruct function
    bool internal locked = false;
    function destroyContract() public contractOwnerOnly {
        address payable receiver = payable(owner);
        selfdestruct(receiver);
    }

    //Emergency
    bool public contractStopped = false;

    function toggleContactStopped() public contractOwnerOnly {
        contractStopped = !contractStopped;
    }


    constructor() public {
        ERC20 e = new ERC20(); //deploying a new contract
        erc20Contract = e;
        owner = msg.sender; //setting owner of the token contract
        supplyLimit = 10000;
        conversionRate = 100;
    }

    //Core Functions

    //cashing in ether for DT token
    // ether will be sent into this contract 
    function getCredit() public payable stoppedInEmergency {
        uint256 amt = msg.value / 10000000000000000; // exchange rate for 1Eth : 100DT
        require(
            erc20Contract.totalSupply() + amt <= supplyLimit,
            "The top-up value is more than the supply limit!"
        );
        //minting the DT token and transfering the token to sender acct
        erc20Contract.mint(msg.sender, amt);
    }

    //check amount of token one has
    function checkCredit() public view returns (uint256) {
        return erc20Contract.balanceOf(tx.origin);
    }

    //transfer token from sender to recipient
    function transferToken(
        address sender,
        address recipient,
        uint256 tokens
    ) public stoppedInEmergency {
        erc20Contract.transferFrom(sender, recipient, tokens);
    }
    
    function cashOut(uint256 amt) public noReEntrant stoppedInEmergency {
        erc20Contract.returned(amt);
        locked = true;
        address payable recipient = payable(tx.origin);
        recipient.transfer(amt*10000000000000000);
        locked = false;
    }

    //Getter and Setter Functions
    //getter function for owner of contract
    function getOwner() public view returns (address) {
        return owner;
    }

    //setter for conversion
    function setConversionRate(uint256 rate) public contractOwnerOnly {
        conversionRate = rate;
    }

    //getter for conversion
    function getConversionRate() public view returns (uint256) {
        return conversionRate;
    }

    //getter function for token supply
    function getSupply() public view returns (uint256) {
        return supplyLimit - erc20Contract.totalSupply();
    }


}
