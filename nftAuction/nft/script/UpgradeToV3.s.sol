// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/NftAuctionWithOracleUpgradeableV3.sol";

/**
 * @title UpgradeToV3
 * @notice 将已部署的拍卖合约从 V1/V2 升级到带动态手续费的 V3 版本
 *
 * 环境变量：
 * - PRIVATE_KEY        部署/升级使用的钱包私钥
 * - PROXY_ADDRESS      现有 UUPS 代理地址（与 V1/V2 交互的地址）
 * - FEE_RECIPIENT      手续费收款地址（可选，默认使用 owner）
 * - LOW_FEE_BPS        低档手续费（bps，默认 100 = 1%）
 * - HIGH_FEE_BPS       高档手续费（bps，默认 200 = 2%）
 * - FEE_THRESHOLD_USD  手续费档位阈值（默认 1_000e18）
 */
contract UpgradeToV3 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        console2.log("=== Upgrading NftAuction to V3 ===");
        console2.log("Proxy address:", proxyAddress);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 V3 实现合约
        NftAuctionWithOracleUpgradeableV3 newImplementation = new NftAuctionWithOracleUpgradeableV3();
        console2.log("New V3 implementation:", address(newImplementation));

        // 2. 通过 UUPS 接口升级代理
        NftAuctionWithOracleUpgradeableV3 proxy = NftAuctionWithOracleUpgradeableV3(proxyAddress);
        proxy.upgradeToAndCall(address(newImplementation), "");

        // 3. 读取 owner，用于默认手续费地址
        address owner = proxy.owner();

        // 4. 初始化 / 更新 V3 手续费参数
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);
        uint96 lowFeeBps = uint96(vm.envOr("LOW_FEE_BPS", uint256(100)));   // 默认 1%
        uint96 highFeeBps = uint96(vm.envOr("HIGH_FEE_BPS", uint256(200))); // 默认 2%
        uint256 feeThresholdUSD = vm.envOr("FEE_THRESHOLD_USD", uint256(1_000e18));

        // 可能已经初始化过 initializeV3，如果是第一次升级则会成功，如果已经初始化则需要改为 setFeeParams
        try proxy.initializeV3(feeRecipient, lowFeeBps, highFeeBps, feeThresholdUSD) {
            console2.log("Called initializeV3 successfully");
        } catch {
            console2.log("initializeV3 already called, updating fee params via setFeeParams");
            proxy.setFeeParams(feeRecipient, lowFeeBps, highFeeBps, feeThresholdUSD);
        }

        console2.log("Owner:", owner);
        console2.log("Version V3:", proxy.getVersionV3());

        vm.stopBroadcast();

        console2.log("\n=== Upgrade Summary (V3) ===");
        console2.log("Proxy (unchanged):", proxyAddress);
        console2.log("New Implementation:", address(newImplementation));
        console2.log("Fee recipient:", feeRecipient);
        console2.log("Low fee bps:", lowFeeBps);
        console2.log("High fee bps:", highFeeBps);
        console2.log("Fee threshold (USD):", feeThresholdUSD);
    }
}


