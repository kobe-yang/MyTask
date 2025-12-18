// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title MockPriceFeed
 * @notice Mock 价格聚合器，用于测试
 * @dev 可以手动设置价格，模拟 Chainlink 价格聚合器
 * 0xddd19C335D12b4F7613EA6D4cBBd8Ea0f61D3c7B
 * ⚠️ 警告：此合约仅用于测试网，不应部署到主网！
 */
contract MockPriceFeed is AggregatorV3Interface {
    int256 private _price;
    uint8 private constant _decimals = 8;
    string private _description;
    uint256 private _updatedAt;
    uint80 private _roundId;
    
    address public owner;

    event PriceUpdated(int256 oldPrice, int256 newPrice, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    /**
     * @notice 构造函数
     * @param initialPrice 初始价格（8 位小数，例如：$1.00 = 100000000）
     * @param priceDescription 价格描述（例如："MyToken / USD"）
     */
    constructor(int256 initialPrice, string memory priceDescription) {
        require(initialPrice > 0, "Price must be positive");
        _price = initialPrice;
        _description = priceDescription;
        _updatedAt = block.timestamp;
        _roundId = 1;
        owner = msg.sender;
    }

    /**
     * @notice 返回价格精度（Chainlink 标准为 8 位小数）
     */
    function decimals() external pure override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice 返回价格描述
     */
    function description() external view override returns (string memory) {
        return _description;
    }

    /**
     * @notice 返回版本号
     */
    function version() external pure override returns (uint256) {
        return 3;
    }

    /**
     * @notice 获取指定轮次的价格数据
     * @param roundIdParam 轮次 ID
     */
    function getRoundData(uint80 roundIdParam)
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (roundIdParam, _price, block.timestamp, _updatedAt, roundIdParam);
    }

    /**
     * @notice 获取最新价格数据
     */
    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _price, block.timestamp, _updatedAt, _roundId);
    }

    /**
     * @notice 更新价格（仅用于测试）
     * @param newPrice 新价格（8 位小数，例如：$2.00 = 200000000）
     */
    function updatePrice(int256 newPrice) external onlyOwner {
        require(newPrice > 0, "Price must be positive");
        int256 oldPrice = _price;
        _price = newPrice;
        _updatedAt = block.timestamp;
        _roundId++;
        emit PriceUpdated(oldPrice, newPrice, block.timestamp);
    }

    /**
     * @notice 获取当前价格
     * @return 当前价格（8 位小数）
     */
    function getPrice() external view returns (int256) {
        return _price;
    }

    /**
     * @notice 获取最后更新时间
     * @return 最后更新时间戳
     */
    function getUpdatedAt() external view returns (uint256) {
        return _updatedAt;
    }

    /**
     * @notice 获取当前轮次 ID
     * @return 当前轮次 ID
     */
    function getRoundId() external view returns (uint80) {
        return _roundId;
    }
}

