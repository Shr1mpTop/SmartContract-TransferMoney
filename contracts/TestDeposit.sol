// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract TestDeposit {
    mapping(address => uint256) public balances;

    // 查询当前用户的余额
    function viewMoney() public view returns (uint256) {
        return balances[msg.sender];
    }

    // 存款函数：先查询当前余额，加上存款金额，然后更新并显示新余额
    function depositMoney() public payable {
        uint256 currentBalance = balances[msg.sender];
        uint256 newBalance = currentBalance + msg.value;
        balances[msg.sender] = newBalance;

        // 使用 console.log 显示信息（仅在测试环境中可见）
        console.log("Current balance before deposit: %s", currentBalance);
        console.log("Deposited amount: %s", msg.value);
        console.log("New balance after deposit: %s", newBalance);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}