// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/NftAuctionWithOracleUpgradeableV2.sol";

/**
 * @title UpgradeToV2
 * @notice 升级拍卖合约到 V2 版本
 *Proxy (unchanged): 0xB8BbC68e2f18304c4e8C77481E90164CBa17428A
 *New Implementation: 0x8180A719a5ba26D75B5f288b9Eed43fB6BDcFFa0
 */
contract UpgradeToV2 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        
        console2.log("=== Upgrading to V2 ===");
        console2.log("Proxy address:", proxyAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署 V2 实现合约
        NftAuctionWithOracleUpgradeableV2 newImplementation = new NftAuctionWithOracleUpgradeableV2();
        console2.log("New V2 implementation:", address(newImplementation));
        
        // 2. 升级代理指向 V2
        // 通过代理调用 upgradeToAndCall（UUPS 模式）
        NftAuctionWithOracleUpgradeableV2 proxy = NftAuctionWithOracleUpgradeableV2(proxyAddress);
        proxy.upgradeToAndCall(address(newImplementation), "");
        
        // 3. 验证升级
        console2.log("Version after upgrade:", proxy.VERSION());
        console2.log("Owner:", proxy.owner());
        
        vm.stopBroadcast();
        
        console2.log("\n=== Upgrade Summary ===");
        console2.log("Proxy (unchanged):", proxyAddress);
        console2.log("New Implementation:", address(newImplementation));
        console2.log("Version:", uint256(2));
    }
}

