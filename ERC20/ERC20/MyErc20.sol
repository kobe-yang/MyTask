// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


// 测试地址 ： https://sepolia.etherscan.io/tx/0xa3a575666d0f6de77c417df63486028d43ca9e2178d567b1656abf384eee51b6
// 合约地址 0x5b14761cADC31ef3c0a1d89A356117c64c8c6FEd

contract MyErc20 {

    string public name = "USDC";
    string public symbol = "USDC";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply * 10 ** decimals;
        balanceOf[msg.sender] = totalSupply;
        owner = msg.sender;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "invalid address");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(from != address(0), "invalid address");
        require(balanceOf[from] >= amount, "insufficient balance");
    
        totalSupply -= amount;
        balanceOf[from] -= amount;
        emit Transfer(from, address(0), amount);
    }
    
    function transfer(address to, uint256 amount) external returns (bool success) {
        require(balanceOf[msg.sender] >= amount, "insufficient balance");
        require(to != address(0), "invalid address");
        
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        
        emit Transfer(msg.sender, to, amount);
        success = true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool success) {
        require(spender != address(0), "invalid address");
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        success = true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool success) {
        require(from != address(0), "invalid address");
        require(to != address(0), "invalid address");
        require(balanceOf[from] >= amount, "insufficient balance");
        require(allowance[from][msg.sender] >= amount, "insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        success = true;
    }
    
}