// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BeggingContract.sol";

contract DeployBeggingContract is Script {
    function run() external {
        // 从环境变量中读取部署私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // 部署合约
        BeggingContract begging = new BeggingContract();

        vm.stopBroadcast();

        // 在日志中打印部署地址，方便查看
        console2.log("BeggingContract deployed at:", address(begging));
    }
}


