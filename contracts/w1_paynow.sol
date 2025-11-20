// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Weixin {  
    
    uint amount;
    address sender;
    address receiver;
    address owner;

    constructor() {
        owner = msg.sender;
        console.log(owner); 
    }

    function transferMoney(address _sender, address _receiver, uint _amount) public {
        sender = _sender;   
        receiver = _receiver;
        amount = _amount;
        console.log(sender, receiver, amount);
    }

    function view_money() public view returns (address,address,uint){
        return(sender,receiver,amount);
    }
}