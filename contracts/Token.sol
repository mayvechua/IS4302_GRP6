// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import "./ERC20.sol";


contract Token {
    ERC20 erc20Contract;
    uint256 supplyLimit;
    address owner;
    uint256 conversionRate;

    // mutex: prevent re-entrant
    bool locked = false;
    modifier noReEntrant {
        require(!locked, "No re-entrancy");
        _;
    }
    modifier ownerOnly {
        require (msg.sender == owner, "you are not allowed to use this function");
        _;
    }

   bool public contractStopped = false;
    modifier stoppedInEmergency {
        if (!contractStopped) _;
    }


    constructor() public {
        ERC20 e = new ERC20(); //deploying a new contract 
        erc20Contract = e;
        owner = msg.sender; //setting owner of the token contract
        supplyLimit = 10000;
        conversionRate= 100;
    }

    //cashing in ether for DT token 
    function getCredit() public payable  stoppedInEmergency {
        uint256 amt = msg.value / 10000000000000000; // exchange rate for 1Eth : 100DT
        require(erc20Contract.totalSupply() + amt <= supplyLimit);
        //minting the DT token and transfering the token to sender acct
        erc20Contract.mint(msg.sender, amt);
    }

    //check amount of token one has 
    function checkCredit() public view returns (uint256) {
        return erc20Contract.balanceOf(tx.origin);
    }

    //transfer token from sender to recipient 
    function transferToken(address sender, address recipient, uint256 tokens) public   stoppedInEmergency {
        erc20Contract.transferFrom(sender,recipient,tokens);
    } 

    //get owner of contract 
    function getOwner() public view returns (address) {
        return owner;
    }
    //setter for conversion
    function setConversionRate(uint256 rate) public ownerOnly  {
        conversionRate= rate;
        
    }
    //getter for conversion 
    function getConversionRate() public view returns (uint256) {
         return conversionRate;
        
    }



    //get token supply
    function getSupply() public view returns (uint256) {
        return supplyLimit - erc20Contract.totalSupply(); 
    }

    function cashOut(uint256 amt) public noReEntrant  stoppedInEmergency {
        erc20Contract.returned(amt);
        locked = true;
        address payable recipient = payable (tx.origin);
        recipient.transfer(amt/0.01 ether);
         locked = false;
    }
    

        // self-destruct function 
     function destroyContract() public ownerOnly {
        address payable receiver = payable(owner);
         selfdestruct(receiver);
     }

     //Emergency 
    function toggleContactStopped() public  ownerOnly {
        contractStopped = !contractStopped;
    }


}