// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PriceOracleOfficial.sol";

/**
 * @title DeployPriceOracle
 * @notice 部署 PriceOracleOfficial 合约的脚本
 * @dev 支持本地和 Sepolia 测试网部署，包含初始化步骤
 */
contract DeployPriceOracle is Script {
    // Sepolia 测试网价格聚合器地址
    // 参考: https://docs.chain.link/data-feeds/price-feeds/addresses
    address constant SEPOLIA_ETH_USD_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address constant SEPOLIA_BTC_USD_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
    
    // Sepolia 测试网代币地址（用于设置价格聚合器）
    // 注意：这些地址在测试网上可能不存在，仅作示例
    // address constant SEPOLIA_USDC = 0x...;
    
    // 以太坊主网价格聚合器地址（用于参考）
    // address constant MAINNET_ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    // address constant MAINNET_USDC_USD_FEED = 0x8fFfFfd4AfB6115b04Bd6860E2415C89C1C7C4b8;

    function run() external returns (PriceOracleOfficial) {
        // 从环境变量读取部署者私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 获取 ETH/USD 价格聚合器地址（可以从环境变量读取，默认使用 Sepolia）
        address ethUsdPriceFeed = vm.envOr("ETH_USD_PRICE_FEED", SEPOLIA_ETH_USD_FEED);

        console2.log("==========================================");
        console2.log("Step 1: Deploying PriceOracleOfficial...");
        console2.log("Deployer:", vm.addr(deployerPrivateKey));
        console2.log("ETH/USD Price Feed:", ethUsdPriceFeed);
        console2.log("==========================================");

        vm.startBroadcast(deployerPrivateKey);

        // 部署 PriceOracleOfficial 合约
        PriceOracleOfficial oracle = new PriceOracleOfficial(ethUsdPriceFeed);

        console2.log("==========================================");
        console2.log("Step 2: Initializing contract...");
        console2.log("==========================================");

        // 初始化步骤 1: 验证部署
        console2.log("2.1 Verifying deployment...");
        require(address(oracle) != address(0), "Deployment failed");
        require(oracle.owner() == vm.addr(deployerPrivateKey), "Owner mismatch");
        console2.log("   [OK] Contract deployed successfully");
        console2.log("   [OK] Owner verified:", oracle.owner());

        // 初始化步骤 2: 验证 ETH 价格查询
        console2.log("2.2 Verifying ETH price feed...");
        try oracle.getEthPriceInUSD() returns (uint256 price) {
            require(price > 0, "Invalid ETH price");
            console2.log("   [OK] ETH price feed working");
            console2.log("   [OK] ETH price:", price);
        } catch {
            console2.log("   [WARN] Could not fetch ETH price (may be expected on local network)");
        }

        // 初始化步骤 3: 设置价格过期阈值（可选，默认 1 小时）
        uint256 staleThreshold = vm.envOr("STALE_PRICE_THRESHOLD", uint256(3600)); // 默认 1 小时
        if (staleThreshold != 3600) {
            console2.log("2.3 Setting stale price threshold...");
            oracle.setStalePriceThreshold(staleThreshold);
            console2.log("   [OK] Stale price threshold set to:", staleThreshold, "seconds");
        } else {
            console2.log("2.3 Using default stale price threshold (3600 seconds)");
        }

        // 初始化步骤 4: 设置代币价格聚合器（可选，从环境变量读取）
        // 示例：设置 BTC/USD 价格聚合器
        address btcToken = vm.envOr("BTC_TOKEN_ADDRESS", address(0));
        address btcPriceFeed = vm.envOr("BTC_USD_PRICE_FEED", address(0));
        
        if (btcToken != address(0) && btcPriceFeed != address(0)) {
            console2.log("2.4 Setting BTC/USD price feed...");
            oracle.setTokenPriceFeed(btcToken, btcPriceFeed);
            console2.log("   [OK] BTC price feed set");
            console2.log("   Token:", btcToken);
            console2.log("   Price Feed:", btcPriceFeed);
        } else {
            // 如果没有设置，可以设置一个示例（Sepolia BTC/USD）
            // 注意：需要有效的代币地址
            console2.log("2.4 Skipping token price feed setup (set BTC_TOKEN_ADDRESS and BTC_USD_PRICE_FEED to enable)");
        }

        // 初始化步骤 5: 验证价格聚合器信息
        console2.log("2.5 Verifying price feed info...");
        try oracle.getEthPriceFeedInfo() returns (uint8 decimals, string memory description, uint256 version) {
            console2.log("   [OK] Price feed decimals:", decimals);
            console2.log("   [OK] Price feed description:", description);
            console2.log("   [OK] Price feed version:", version);
        } catch {
            console2.log("   [WARN] Could not fetch price feed info");
        }

        vm.stopBroadcast();

        console2.log("==========================================");
        console2.log("Deployment and Initialization Complete!");
        console2.log("==========================================");
        console2.log("Contract Address:", address(oracle));
        console2.log("Owner:", vm.addr(deployerPrivateKey));
        console2.log("ETH/USD Price Feed:", ethUsdPriceFeed);
        console2.log("Stale Price Threshold:", oracle.stalePriceThreshold(), "seconds");
        console2.log("==========================================");

        return oracle;
    }
}

