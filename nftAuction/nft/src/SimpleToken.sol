// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin/contracts/token/ERC20/ERC20.sol";
import "openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SimpleToken
 * @notice 简单的 ERC20 代币合约
 * @dev 支持铸造、销毁和 Permit 签名授权
 * 合约地址 0xf4AF69986484E9847F848F5c4F8686D62EBC9102
 */
contract SimpleToken is ERC20, ERC20Burnable, ERC20Permit, Ownable {
    
    /**
     * @notice 构造函数
     * @param name 代币名称
     * @param symbol 代币符号
     * @param initialSupply 初始供应量（会乘以 10^18）
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) ERC20Permit(name) Ownable(msg.sender) {
        // 铸造初始供应量给部署者
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }
    
    /**
     * @notice 铸造新代币（仅 owner）
     * @param to 接收地址
     * @param amount 数量（最小单位）
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

