// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PriceOracleOfficial
 * @notice 使用 Chainlink 官方库实现价格预言机
 * @dev 直接使用 smartcontractkit/chainlink-brownie-contracts 库的接口
 * 
 * 与 PriceOracle.sol 的区别：
 * - 使用官方库的 AggregatorV3Interface，而不是自定义接口
 * - 更可靠，因为使用的是 Chainlink 官方维护的代码
 * - 自动获得库的更新和修复
 */
contract PriceOracleOfficial is Ownable {
    // ETH/USD 价格聚合器
    AggregatorV3Interface public ethUsdPriceFeed;

    // ERC20 代币地址 => 价格聚合器
    mapping(address => AggregatorV3Interface) public tokenPriceFeeds;

    // 价格过期时间阈值（秒）
    uint256 public stalePriceThreshold = 3600 * 24; // 1 小时

    event PriceFeedUpdated(address indexed token, address indexed priceFeed);
    event StalePriceThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    /**
     * @notice 构造函数
     * @param _ethUsdPriceFeed ETH/USD 价格聚合器地址
     */
    constructor(address _ethUsdPriceFeed) Ownable(msg.sender) {
        require(_ethUsdPriceFeed != address(0), "Invalid price feed address");
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
    }

    /**
     * @notice 设置 ERC20 代币的价格聚合器
     * @param token ERC20 代币地址
     * @param priceFeed 价格聚合器地址
     */
    function setTokenPriceFeed(address token, address priceFeed) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(priceFeed != address(0), "Invalid price feed address");
        tokenPriceFeeds[token] = AggregatorV3Interface(priceFeed);
        emit PriceFeedUpdated(token, priceFeed);
    }

    /**
     * @notice 设置价格过期时间阈值
     * @param _threshold 新的阈值（秒）
     */
    function setStalePriceThreshold(uint256 _threshold) external onlyOwner {
        uint256 oldThreshold = stalePriceThreshold;
        stalePriceThreshold = _threshold;
        emit StalePriceThresholdUpdated(oldThreshold, _threshold);
    }


    /**
     * @notice 获取 ETH 的美元价格（8 位小数）
     * @return price ETH 价格（例如：$3000.50 = 300050000000）
     */
    function getEthPrice() public view returns (int256) {
        (int256 price, ) = _getPriceData(ethUsdPriceFeed);
        return price;
    }

    /**
     * @notice 获取 ETH 的美元价格（18 位小数，Wei 精度）
     * @return price ETH 价格，精度为 1e18
     */
    function getEthPriceInUSD() public view returns (uint256) {
        (int256 price, ) = _getPriceData(ethUsdPriceFeed);
        // 从 8 位小数转换为 18 位小数
        return uint256(price) * 1e10;
    }

    /**
     * @notice 获取 ERC20 代币的美元价格（8 位小数）
     * @param token ERC20 代币地址
     * @return price 代币价格
     */
    function getTokenPrice(address token) public view returns (int256) {
        AggregatorV3Interface priceFeed = tokenPriceFeeds[token];
        require(address(priceFeed) != address(0), "Token price feed not set");
        (int256 price, ) = _getPriceData(priceFeed);
        return price;
    }

    /**
     * @notice 获取 ERC20 代币的美元价格（18 位小数）
     * @param token ERC20 代币地址
     * @return price 代币价格，精度为 1e18
     */
    function getTokenPriceInUSD(address token) public view returns (uint256) {
        AggregatorV3Interface priceFeed = tokenPriceFeeds[token];
        require(address(priceFeed) != address(0), "Token price feed not set");
        (int256 price, ) = _getPriceData(priceFeed);
        return uint256(price) * 1e10;
    }

    /**
     * @notice 获取 ETH 和代币的价格信息（包含更新时间）
     * @param token ERC20 代币地址（可选，address(0) 表示只查询 ETH）
     * @return ethPrice ETH 价格（18 位小数）
     * @return tokenPrice 代币价格（18 位小数，如果 token 为 address(0) 则返回 0）
     * @return ethUpdatedAt ETH 价格更新时间
     * @return tokenUpdatedAt 代币价格更新时间
     */
    function getPrices(address token)
        public
        view
        returns (
            uint256 ethPrice,
            uint256 tokenPrice,
            uint256 ethUpdatedAt,
            uint256 tokenUpdatedAt
        )
    {
        (int256 ethPriceRaw, uint256 ethUpdated) = _getPriceData(ethUsdPriceFeed);
        ethPrice = uint256(ethPriceRaw) * 1e10;
        ethUpdatedAt = ethUpdated;

        if (token != address(0)) {
            AggregatorV3Interface tokenFeed = tokenPriceFeeds[token];
            require(address(tokenFeed) != address(0), "Token price feed not set");
            (int256 tokenPriceRaw, uint256 tokenUpdated) = _getPriceData(tokenFeed);
            tokenPrice = uint256(tokenPriceRaw) * 1e10;
            tokenUpdatedAt = tokenUpdated;
        }
    }

    /**
     * @notice 将 ETH 数量转换为美元价值
     * @param ethAmount ETH 数量（Wei，18 位小数）
     * @return usdValue 美元价值（18 位小数）
     */
    function ethToUSD(uint256 ethAmount) public view returns (uint256) {
        uint256 ethPrice = getEthPriceInUSD();
        return (ethAmount * ethPrice) / 1e18;
    }

    /**
     * @notice 将代币数量转换为美元价值
     * @param token ERC20 代币地址
     * @param tokenAmount 代币数量（假设 18 位小数）
     * @return usdValue 美元价值（18 位小数）
     */
    function tokenToUSD(address token, uint256 tokenAmount)
        public
        view
        returns (uint256)
    {
        uint256 tokenPrice = getTokenPriceInUSD(token);
        return (tokenAmount * tokenPrice) / 1e18;
    }

    /**
     * @notice 获取价格聚合器的详细信息（使用官方接口的额外功能）
     * @param priceFeed 价格聚合器地址
     * @return decimals 精度（通常是 8）
     * @return description 描述信息
     * @return version 版本号
     */
    function getPriceFeedInfo(AggregatorV3Interface priceFeed)
        public
        view
        returns (
            uint8 decimals,
            string memory description,
            uint256 version
        )
    {
        require(address(priceFeed) != address(0), "Price feed not set");
        return (
            priceFeed.decimals(),
            priceFeed.description(),
            priceFeed.version()
        );
    }

    /**
     * @notice 获取 ETH 价格聚合器的详细信息
     * @return decimals 精度
     * @return description 描述
     * @return version 版本
     */
    function getEthPriceFeedInfo()
        public
        view
        returns (
            uint8 decimals,
            string memory description,
            uint256 version
        )
    {
        return getPriceFeedInfo(ethUsdPriceFeed);
    }

     /**
     * @notice 获取价格数据（内部函数）
     * @param priceFeed 价格聚合器接口
     * @return price 价格（8 位小数）
     * @return updatedAt 更新时间戳
     */
    function _getPriceData(AggregatorV3Interface priceFeed)
        internal
        view
        returns (int256 price, uint256 updatedAt)
    {
        require(address(priceFeed) != address(0), "Price feed not set");

        (
            uint80 roundId,
            int256 rawPrice,
            , // startedAt - 未使用
            uint256 rawUpdatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();

        require(rawPrice > 0, "Invalid price");
        require(rawUpdatedAt > 0, "Price feed not updated");
        require(answeredInRound >= roundId, "Stale price");

        // 检查价格是否过期
        require(
            block.timestamp - rawUpdatedAt <= stalePriceThreshold,
            "Price too stale"
        );

        return (rawPrice, rawUpdatedAt);
    }
}

