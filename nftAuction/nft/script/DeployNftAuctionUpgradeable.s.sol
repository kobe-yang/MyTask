// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/NftAuctionWithOracleUpgradeable.sol";

/**
 * @title DeployNftAuctionUpgradeable
 * @notice 部署可升级的 NFT 拍卖合约（UUPS 模式）
 */
contract DeployNftAuctionUpgradeable is Script {

    address constant SEPOLIA_ETH_USD_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    function run() external {
        // 从环境变量读取配置
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
     //  address ethUsdPriceFeed = vm.envAddress("ETH_USD_PRICE_FEED");
        address owner = vm.envOr("OWNER_ADDRESS", vm.addr(deployerPrivateKey));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署实现合约
        NftAuctionWithOracleUpgradeable implementation = new NftAuctionWithOracleUpgradeable();
        console2.log("Implementation deployed at:", address(implementation));
        
        // 2. 编码初始化数据
        bytes memory initData = abi.encodeWithSelector(
            NftAuctionWithOracleUpgradeable.initialize.selector,
            SEPOLIA_ETH_USD_FEED,
            owner
        );
        
        // 3. 部署代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console2.log("Proxy deployed at:", address(proxy));
        
        // 4. 验证部署
        NftAuctionWithOracleUpgradeable auction = NftAuctionWithOracleUpgradeable(address(proxy));
        console2.log("Owner:", auction.owner());
        console2.log("Version:", auction.VERSION());
        
        vm.stopBroadcast();
        
        console2.log("\n=== Deployment Summary ===");
        console2.log("Implementation:", address(implementation));
        console2.log("Proxy (use this):", address(proxy));
    }
}

/**
 * @title UpgradeNftAuction
 * @notice 升级合约到新版本
 */
contract UpgradeNftAuction is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署新的实现合约
        NftAuctionWithOracleUpgradeable newImplementation = new NftAuctionWithOracleUpgradeable();
        console2.log("New implementation:", address(newImplementation));
        
        // 2. 升级代理指向新实现
        NftAuctionWithOracleUpgradeable proxy = NftAuctionWithOracleUpgradeable(proxyAddress);
        proxy.upgradeToAndCall(address(newImplementation), "");
        
        console2.log("Upgrade complete!");
        console2.log("Proxy address (unchanged):", proxyAddress);
        
        vm.stopBroadcast();
    }
}

