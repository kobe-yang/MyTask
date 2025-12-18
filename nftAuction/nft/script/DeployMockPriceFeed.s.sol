// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/mocks/MockPriceFeed.sol";

/**
 * @title DeployMockPriceFeed
 * @notice 部署 Mock 价格聚合器的脚本
 * @dev 仅用于测试网，不应部署到主网
 */
contract DeployMockPriceFeed is Script {
    function run() external returns (MockPriceFeed) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 从环境变量读取初始价格，默认 $1.00
        // 价格以 8 位小数表示：$1.00 = 100000000
        int256 initialPrice = int256(vm.envOr("INITIAL_PRICE", uint256(100000000)));
        
        // 从环境变量读取描述，默认 "TestToken / USD"
        string memory description = vm.envOr(
            "PRICE_DESCRIPTION",
            string("TestToken / USD")
        );
        
        console2.log("==========================================");
        console2.log("Deploying MockPriceFeed...");
        console2.log("Deployer:", vm.addr(deployerPrivateKey));
        console2.log("Initial Price:", uint256(initialPrice), "(8 decimals)");
        console2.log("Description: TestToken / USD");
        console2.log("==========================================");
        
        vm.startBroadcast(deployerPrivateKey);
        
        MockPriceFeed mockFeed = new MockPriceFeed(initialPrice, description);
        
        vm.stopBroadcast();
        
        console2.log("==========================================");
        console2.log("MockPriceFeed deployed successfully!");
        console2.log("Contract Address:", address(mockFeed));
        console2.log("Owner:", vm.addr(deployerPrivateKey));
        console2.log("Current Price:", uint256(mockFeed.getPrice()));
        console2.log("==========================================");
        console2.log("");
        console2.log("[WARN] This is a MOCK contract for testing only!");
        console2.log("       Do NOT deploy to mainnet!");
        console2.log("");
        console2.log("Next steps:");
        console2.log("1. Set price feed in auction contract:");
        console2.log("   cast send <AUCTION_ADDRESS> \\");
        console2.log("     \"setTokenPriceFeed(address,address)\" \\");
        console2.log("     <TOKEN_ADDRESS> \\");
        console2.log("     <MOCK_PRICE_FEED_ADDRESS> \\");
        console2.log("     --rpc-url $SEPOLIA_RPC_URL \\");
        console2.log("     --private-key $PRIVATE_KEY");
        console2.log("");
        console2.log("2. Update price (if needed):");
        console2.log("   cast send <MOCK_PRICE_FEED_ADDRESS> \\");
        console2.log("     \"updatePrice(int256)\" \\");
        console2.log("     200000000 \\");
        console2.log("     --rpc-url $SEPOLIA_RPC_URL \\");
        console2.log("     --private-key $PRIVATE_KEY");
        console2.log("==========================================");
        
        return mockFeed;
    }
}

