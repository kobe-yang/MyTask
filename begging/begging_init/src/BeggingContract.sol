// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
任务目标
使用 Solidity 编写一个合约，允许用户向合约地址发送以太币。
记录每个捐赠者的地址和捐赠金额。
允许合约所有者提取所有捐赠的资金。

任务步骤
编写合约
创建一个名为 BeggingContract 的合约。
合约应包含以下功能：
一个 mapping 来记录每个捐赠者的捐赠金额。
一个 donate 函数，允许用户向合约发送以太币，并记录捐赠信息。
一个 withdraw 函数，允许合约所有者提取所有资金。
一个 getDonation 函数，允许查询某个地址的捐赠金额。
使用 payable 修饰符和 address.transfer 实现支付和提款。
 */
contract BeggingContract {
    address public owner;
    uint256 public beggingAmount;
    
    uint256 public totalDonations;

    //一个 mapping 来记录每个捐赠者的捐赠金额。
    mapping(address => uint256) public donations;

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    event Donate(address indexed donor, uint256 amount);

    event Withdraw(uint256 amount);

    constructor() {
        owner = msg.sender;
    }
    // 1.允许用户向合约发送以太币，并记录捐赠信息。
    function donate() public payable {
        require(msg.value > 0, "amount must be greater than 0");
        donations[msg.sender] += msg.value;
        totalDonations += msg.value;
        emit Donate(msg.sender, msg.value);
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "no balance");

        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "withdraw failed");
        emit Withdraw(balance);
    }

    function getDonation(address _address) public view returns (uint256) {
        require(donations[_address] > 0, "no donation");
        return donations[_address];
    }       


}