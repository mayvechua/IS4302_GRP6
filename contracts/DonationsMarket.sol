// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import "./Token.sol";
//import "eth-heap/contracts/Heap.sol";

contract DonationsMarket {

    Token tokenContract;
    
     constructor(Token tokenAddress) public {
        tokenContract = tokenAddress;
        mapping(uint256 => uint256) tokenList;

    }

    event listedEvent(uint256 tokenId);
    event unlistedEvent(uint256 tokenId);


    //list a token for sale using token id
    function list(uint256 tokenId) public {
       require(msg.sender == tokenContract.getOwner(tokenId));
       tokenList[tokenId] = tokenContract.getTokenAmt(tokenId);
       emit listedEvent(tokenId);
    }

    function unlist(uint256 tokenId) public {
       require(msg.sender == tokenContract.getOwner(tokenId));
       tokenList[tokenId] = 0;
       emit unlistedEvent(tokenId);
  }

    // if amount of token left <1, unlist token
    function checkRemainder(uint256 tokenId) public {

        if(tokenContract.getTokenAmt(tokenId) < 1){
            unlist(tokenId);
        }
 }

    // for recipients to input requests to be sent to token contract
    function tokenRequest(uint256 tokenId, uint256 amt, uint256 deadline) public {
        return tokenContract.addRequest(tokenId, msg.sender, amt, deadline);
    }

    //matching algorithm
    
}
