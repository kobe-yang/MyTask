// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/SimpleToken.sol";

/**
 * @title DeploySimpleToken
 * @notice 部署 SimpleToken ERC20 代币
 */
contract DeploySimpleToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 代币参数（可通过环境变量配置）
        string memory name = vm.envOr("TOKEN_NAME", string("Simple Token"));
        string memory symbol = vm.envOr("TOKEN_SYMBOL", string("STK"));
        uint256 initialSupply = vm.envOr("INITIAL_SUPPLY", uint256(1000000)); // 100万
        
        vm.startBroadcast(deployerPrivateKey);
        
        SimpleToken token = new SimpleToken(name, symbol, initialSupply);
        
        console2.log("Token deployed at:", address(token));
        console2.log("Name:", token.name());
        console2.log("Symbol:", token.symbol());
        console2.log("Total Supply:", token.totalSupply());
        console2.log("Owner:", token.owner());
        
        vm.stopBroadcast();
    }
}

