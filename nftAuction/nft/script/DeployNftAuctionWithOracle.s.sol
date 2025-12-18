// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/NftAuctionWithOracle.sol";

/**
 * @title DeployNftAuctionWithOracle
 * @notice 部署集成价格预言机的 NFT 拍卖合约
 * @dev 支持本地和 Sepolia 测试网部署
 */
contract DeployNftAuctionWithOracle is Script {
    // Sepolia 测试网 ETH/USD 价格聚合器地址
    address constant SEPOLIA_ETH_USD_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    
    // Sepolia 测试网代币价格聚合器（可选）
    // address constant SEPOLIA_USDC_USD_FEED = 0xA2F78ab2355fe2f984D808B5CeE7FD6A2bD5F3d5;
    // address constant SEPOLIA_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function run() external returns (NftAuctionWithOracle) {
        // 从环境变量读取部署者私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 获取 ETH/USD 价格聚合器地址
        address ethUsdPriceFeed = vm.envOr("ETH_USD_PRICE_FEED", SEPOLIA_ETH_USD_FEED);

        console2.log("==========================================");
        console2.log("Deploying NftAuctionWithOracle...");
        console2.log("Deployer:", vm.addr(deployerPrivateKey));
        console2.log("ETH/USD Price Feed:", ethUsdPriceFeed);
        console2.log("==========================================");

        vm.startBroadcast(deployerPrivateKey);

        // 部署 NftAuctionWithOracle 合约
        NftAuctionWithOracle auction = new NftAuctionWithOracle(ethUsdPriceFeed);

        console2.log("==========================================");
        console2.log("Step 2: Initializing contract...");
        console2.log("==========================================");

        // 初始化步骤 1: 验证部署
        console2.log("2.1 Verifying deployment...");
        require(address(auction) != address(0), "Deployment failed");
        require(auction.owner() == vm.addr(deployerPrivateKey), "Owner mismatch");
        console2.log("   [OK] Contract deployed successfully");
        console2.log("   [OK] Owner verified:", auction.owner());

        // 初始化步骤 2: 验证 ETH 价格查询
        console2.log("2.2 Verifying ETH price feed...");
        try auction.getEthPriceInUSD() returns (uint256 price) {
            require(price > 0, "Invalid ETH price");
            console2.log("   [OK] ETH price feed working");
            console2.log("   [OK] ETH price:", price);
        } catch {
            console2.log("   [WARN] Could not fetch ETH price (may be expected on local network)");
        }

        // 初始化步骤 3: 设置价格过期阈值（可选）
        uint256 staleThreshold = vm.envOr("STALE_PRICE_THRESHOLD", uint256(3600 * 24)); // 默认 24 小时
        if (staleThreshold != 3600 * 24) {
            console2.log("2.3 Setting stale price threshold...");
            auction.setStalePriceThreshold(staleThreshold);
            console2.log("   [OK] Stale price threshold set to:", staleThreshold, "seconds");
        } else {
            console2.log("2.3 Using default stale price threshold (86400 seconds = 24 hours)");
        }

        // 初始化步骤 4: 设置 ERC20 代币价格聚合器（可选）
        // address usdcToken = vm.envOr("USDC_TOKEN_ADDRESS", address(0));
        // address usdcPriceFeed = vm.envOr("USDC_USD_PRICE_FEED", address(0));
        
        // if (usdcToken != address(0) && usdcPriceFeed != address(0)) {
        //     console2.log("2.4 Setting USDC/USD price feed...");
        //     auction.setTokenPriceFeed(usdcToken, usdcPriceFeed);
        //     console2.log("   [OK] USDC price feed set");
        //     console2.log("   Token:", usdcToken);
        //     console2.log("   Price Feed:", usdcPriceFeed);
        // } else {
        //     console2.log("2.4 Skipping token price feed setup (set USDC_TOKEN_ADDRESS and USDC_USD_PRICE_FEED to enable)");
        // }

        vm.stopBroadcast();

        console2.log("==========================================");
        console2.log("Deployment and Initialization Complete!");
        console2.log("==========================================");
        console2.log("Contract Address:", address(auction));
        console2.log("Owner:", vm.addr(deployerPrivateKey));
        console2.log("ETH/USD Price Feed:", ethUsdPriceFeed);
        console2.log("Stale Price Threshold:", auction.stalePriceThreshold(), "seconds");
        console2.log("==========================================");

        return auction;
    }
}

