// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title PriceOracleLib
 * @notice 价格预言机工具库
 * @dev 提供价格查询和转换的纯函数，可被多个合约复用
 * 
 * 使用方式：
 * ```solidity
 * using PriceOracleLib for AggregatorV3Interface;
 * 
 * uint256 price = priceFeed.getPriceInUSD(staleThreshold);
 * uint256 usdValue = PriceOracleLib.ethToUSD(ethAmount, ethPrice);
 * ```
 */
library PriceOracleLib {
    /**
     * @notice 从价格聚合器获取价格数据
     * @param priceFeed 价格聚合器接口
     * @param staleThreshold 价格过期阈值（秒）
     * @return price 价格（8 位小数）
     * @return updatedAt 更新时间戳
     */
    function getPriceData(
        AggregatorV3Interface priceFeed,
        uint256 staleThreshold
    ) internal view returns (int256 price, uint256 updatedAt) {
        require(address(priceFeed) != address(0), "Price feed not set");

        (
            uint80 roundId,
            int256 rawPrice,
            ,
            uint256 rawUpdatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        require(rawPrice > 0, "Invalid price");
        require(rawUpdatedAt > 0, "Price feed not updated");
        require(answeredInRound >= roundId, "Stale price");
        require(
            block.timestamp - rawUpdatedAt <= staleThreshold,
            "Price too stale"
        );

        return (rawPrice, rawUpdatedAt);
    }

    /**
     * @notice 获取价格（18 位小数，Wei 精度）
     * @param priceFeed 价格聚合器接口
     * @param staleThreshold 价格过期阈值（秒）
     * @return price 价格，精度为 1e18
     */
    function getPriceInUSD(
        AggregatorV3Interface priceFeed,
        uint256 staleThreshold
    ) internal view returns (uint256) {
        (int256 price, ) = getPriceData(priceFeed, staleThreshold);
        // 从 8 位小数转换为 18 位小数
        return uint256(price) * 1e10;
    }

    /**
     * @notice 将 ETH 数量转换为美元价值
     * @param ethAmount ETH 数量（Wei，18 位小数）
     * @param ethPriceInUSD ETH 价格（18 位小数）
     * @return usdValue 美元价值（18 位小数）
     */
    function ethToUSD(
        uint256 ethAmount,
        uint256 ethPriceInUSD
    ) internal pure returns (uint256) {
        return (ethAmount * ethPriceInUSD) / 1e18;
    }

    /**
     * @notice 将代币数量转换为美元价值
     * @param tokenAmount 代币数量（18 位小数）
     * @param tokenPriceInUSD 代币价格（18 位小数）
     * @return usdValue 美元价值（18 位小数）
     */
    function tokenToUSD(
        uint256 tokenAmount,
        uint256 tokenPriceInUSD
    ) internal pure returns (uint256) {
        return (tokenAmount * tokenPriceInUSD) / 1e18;
    }

    /**
     * @notice 比较两个美元价值
     * @param usdValue1 第一个美元价值（18 位小数）
     * @param usdValue2 第二个美元价值（18 位小数）
     * @return isGreater 第一个是否大于第二个
     * @return difference 差值（18 位小数）
     */
    function compareUSD(
        uint256 usdValue1,
        uint256 usdValue2
    ) internal pure returns (bool isGreater, uint256 difference) {
        if (usdValue1 >= usdValue2) {
            return (true, usdValue1 - usdValue2);
        } else {
            return (false, usdValue2 - usdValue1);
        }
    }
}

