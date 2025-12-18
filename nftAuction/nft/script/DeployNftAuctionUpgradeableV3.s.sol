// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/NftAuctionWithOracleUpgradeableV3.sol";

/**
 * @title DeployNftAuctionUpgradeableV3
 * @notice 部署带价格预言机和动态手续费功能的 UUPS 可升级拍卖合约（直接部署到 V3 实现）
 */
contract DeployNftAuctionUpgradeableV3 is Script {
    // 根据需要替换为不同网络的 ETH/USD 预言机地址
    address constant SEPOLIA_ETH_USD_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // 如果未显式设置 OWNER_ADDRESS，则默认使用私钥对应地址
        address owner = vm.envOr("OWNER_ADDRESS", vm.addr(deployerPrivateKey));

        // 手续费收款地址（默认也用 owner，如果需要可在环境变量中单独配置）
        address feeRecipient = vm.envOr("FEE_RECIPIENT", owner);

        // 手续费参数（bps，万分比），可在 .env 中覆盖
        uint96 lowFeeBps = uint96(vm.envOr("LOW_FEE_BPS", uint256(100)));   // 默认 1%
        uint96 highFeeBps = uint96(vm.envOr("HIGH_FEE_BPS", uint256(200))); // 默认 2%
        uint256 feeThresholdUSD = vm.envOr("FEE_THRESHOLD_USD", uint256(1_000e18)); // 默认阈值 1000 USD

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 V3 实现合约
        NftAuctionWithOracleUpgradeableV3 implementation = new NftAuctionWithOracleUpgradeableV3();
        console2.log("V3 implementation deployed at:", address(implementation));

        // 2. 编码 V1/V2 的 initialize 调用（设置价格预言机和 owner）
        bytes memory initData = abi.encodeWithSelector(
            NftAuctionWithOracleUpgradeable.initialize.selector,
            SEPOLIA_ETH_USD_FEED,
            owner
        );

        // 3. 部署 UUPS 代理，并在构造时调用 initialize
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console2.log("Proxy deployed at:", address(proxy));

        // 4. 通过代理调用 V3 的初始化（设置手续费参数）
        NftAuctionWithOracleUpgradeableV3 auction = NftAuctionWithOracleUpgradeableV3(address(proxy));
        auction.initializeV3(feeRecipient, lowFeeBps, highFeeBps, feeThresholdUSD);

        // 5. 基本信息检查
        console2.log("Owner:", auction.owner());
        console2.log("Version V3:", auction.getVersionV3());

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary (V3) ===");
        console2.log("Implementation:", address(implementation));
        console2.log("Proxy (use this address to interact):", address(proxy));
        console2.log("Fee recipient:", feeRecipient);
        console2.log("Low fee bps:", lowFeeBps);
        console2.log("High fee bps:", highFeeBps);
        console2.log("Fee threshold (USD):", feeThresholdUSD);
    }
}


