// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "../src/NftAuctionTransparentUpgradeable.sol";

/**
 * @title DeployNftAuctionTransparent
 * @notice 部署透明代理模式的 NFT 拍卖合约
 */
contract DeployNftAuctionTransparent is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address ethUsdPriceFeed = vm.envAddress("ETH_USD_PRICE_FEED");
        address owner = vm.envOr("OWNER_ADDRESS", vm.addr(deployerPrivateKey));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署实现合约
        NftAuctionTransparentUpgradeable implementation = new NftAuctionTransparentUpgradeable();
        console2.log("Implementation:", address(implementation));
        
        // 2. 编码初始化数据
        bytes memory initData = abi.encodeWithSelector(
            NftAuctionTransparentUpgradeable.initialize.selector,
            ethUsdPriceFeed,
            owner
        );
        
        // 3. 部署透明代理（会自动部署 ProxyAdmin）
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            owner,  // ProxyAdmin 的 owner
            initData
        );
        console2.log("Proxy:", address(proxy));
        
        // 4. 获取 ProxyAdmin 地址
        // 透明代理会自动创建 ProxyAdmin，地址可以通过事件或计算获取
        console2.log("ProxyAdmin owner:", owner);
        
        // 5. 验证
        NftAuctionTransparentUpgradeable auction = NftAuctionTransparentUpgradeable(address(proxy));
        console2.log("Auction owner:", auction.owner());
        console2.log("Version:", auction.VERSION());
        
        vm.stopBroadcast();
        
        console2.log("\n=== Deployment Summary ===");
        console2.log("Implementation:", address(implementation));
        console2.log("Proxy (use this):", address(proxy));
        console2.log("Note: ProxyAdmin is created automatically by TransparentUpgradeableProxy");
    }
}

/**
 * @title UpgradeNftAuctionTransparent
 * @notice 升级透明代理合约
 */
contract UpgradeNftAuctionTransparent is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        address proxyAdminAddress = vm.envAddress("PROXY_ADMIN_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署新的实现合约
        NftAuctionTransparentUpgradeable newImplementation = new NftAuctionTransparentUpgradeable();
        console2.log("New implementation:", address(newImplementation));
        
        // 2. 通过 ProxyAdmin 升级
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddress);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(proxyAddress),
            address(newImplementation),
            ""  // 无需额外初始化调用
        );
        
        console2.log("Upgrade complete!");
        console2.log("Proxy (unchanged):", proxyAddress);
        
        vm.stopBroadcast();
    }
}

