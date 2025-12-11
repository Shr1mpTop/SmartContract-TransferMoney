// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract store_money {
    address customer;
    uint amount;

    function deposit_money(address customer_input, uint amount_input) public {
        customer = customer_input;
        amount = amount_input;
    }

    function deposit_view() public view returns (address, uint) {
        return (customer, amount);
    }
}