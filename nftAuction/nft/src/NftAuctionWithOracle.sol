// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin/contracts/token/ERC721/IERC721.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./libraries/PriceOracleLib.sol";

/**
 * @title NftAuctionWithOracle
 * @notice 集成价格预言机的 NFT 拍卖合约
 * @dev 支持 ETH 和 ERC20 代币出价，自动转换为美元价值显示
 */
contract NftAuctionWithOracle is ReentrancyGuard, Ownable {
    // 使用 PriceOracleLib
    using PriceOracleLib for AggregatorV3Interface;
    
    // ============ 价格预言机相关 ============
    
    // ETH/USD 价格聚合器
    AggregatorV3Interface public ethUsdPriceFeed;
    
    // ERC20 代币地址 => 价格聚合器
    mapping(address => AggregatorV3Interface) public tokenPriceFeeds;
    
    // 价格过期时间阈值（秒）
    uint256 public stalePriceThreshold = 3600 * 24; // 24 小时（测试网推荐）
    
    // ============ 拍卖相关 ============
    
    enum BidType {
        ETH,    // 使用原生 ETH 出价
        ERC20   // 使用 ERC20 代币出价
    }
    
    struct Auction {
        address seller;

        address nftAddress;
        uint256 tokenId;
        uint256 minBidUSD;      // 起拍价（美元，18 位小数）
        uint256 endTime;         // 结束时间（时间戳）
        address highestBidder;   // 当前最高出价者
        uint256 highestBid;      // 当前最高出价（原始金额）
        BidType bidType;         // 出价类型（ETH 或 ERC20）
        address bidToken;         // 如果使用 ERC20，代币地址（ETH 时为 address(0)）
        bool settled;            // 是否已结算
    }
    
    uint256 public nextAuctionId;
    mapping(uint256 => Auction) public auctions;
    
    // ============ 事件 ============
    
    event PriceFeedUpdated(address indexed token, address indexed priceFeed);
    event StalePriceThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 minBidUSD,
        uint256 endTime
    );
    
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        BidType bidType,
        address bidToken,
        uint256 usdValue
    );
    
    event AuctionSettled(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed winner,
        uint256 amount,
        BidType bidType,
        address bidToken
    );
    
    // ============ 构造函数 ============
    
    /**
     * @notice 构造函数
     * @param _ethUsdPriceFeed ETH/USD 价格聚合器地址
     */
    constructor(address _ethUsdPriceFeed) Ownable(msg.sender) {
        require(_ethUsdPriceFeed != address(0), "Invalid price feed address");
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
    }
    
    // ============ 价格预言机功能 ============
    
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
     * @notice 获取 ETH 的美元价格（18 位小数）
     */
    function getEthPriceInUSD() public view returns (uint256) {
        return ethUsdPriceFeed.getPriceInUSD(stalePriceThreshold);
    }
    
    /**
     * @notice 获取 ERC20 代币的美元价格（18 位小数）
     */
    function getTokenPriceInUSD(address token) public view returns (uint256) {
        AggregatorV3Interface priceFeed = tokenPriceFeeds[token];
        require(address(priceFeed) != address(0), "Token price feed not set");
        return priceFeed.getPriceInUSD(stalePriceThreshold);
    }
    
    /**
     * @notice 将 ETH 数量转换为美元价值
     * @param ethAmount ETH 数量（Wei，18 位小数）
     * @return usdValue 美元价值（18 位小数）
     */
    function ethToUSD(uint256 ethAmount) public view returns (uint256) {
        uint256 ethPrice = getEthPriceInUSD();
        return PriceOracleLib.ethToUSD(ethAmount, ethPrice);
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
        return PriceOracleLib.tokenToUSD(tokenAmount, tokenPrice);
    }
    
    // ============ 拍卖功能 ============
    
    /**
     * @notice 创建拍卖（NFT 需要提前 approve 给本合约）
     * @param nftAddress NFT 合约地址
     * @param tokenId NFT Token ID
     * @param minBidUSD 起拍价（美元，18 位小数）
     * @param duration 拍卖持续时间（秒）
     * @return auctionId 拍卖 ID
     */
    function createAuction(
        address nftAddress,
        uint256 tokenId,
        uint256 minBidUSD,
        uint256 duration
    ) external returns (uint256 auctionId) {
        require(duration > 0, "Duration must be > 0");
        require(minBidUSD > 0, "Min bid must be > 0");
        
        auctionId = nextAuctionId++;
        
        // 将 NFT 从卖家转移到拍卖合约托管
        IERC721(nftAddress).transferFrom(msg.sender, address(this), tokenId);
        
        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftAddress: nftAddress,
            tokenId: tokenId,
            minBidUSD: minBidUSD,
            endTime: block.timestamp + duration,
            highestBidder: address(0),
            highestBid: 0,
            bidType: BidType.ETH, // 默认，实际出价时可以改变
            bidToken: address(0),
            settled: false
        });
        
        emit AuctionCreated(
            auctionId,
            msg.sender,
            nftAddress,
            tokenId,
            minBidUSD,
            block.timestamp + duration
        );
    }
    
    /**
     * @notice 使用 ETH 出价
     * @param auctionId 拍卖 ID
     */
    function bidWithETH(uint256 auctionId) external payable nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction not found");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(!auction.settled, "Auction settled");
        
        uint256 currentBid = msg.value;
        uint256 currentBidUSD = ethToUSD(currentBid);
        
        // 检查是否满足最低出价要求
        require(currentBidUSD >= auction.minBidUSD, "Bid below minimum");
        
        // 如果已有出价，检查是否高于当前最高价
        if (auction.highestBidder != address(0)) {
            uint256 highestBidUSD = _getBidUSDValue(
                auction.highestBid,
                auction.bidType,
                auction.bidToken
            );
            require(currentBidUSD > highestBidUSD, "Bid too low");
            
            // 退还上一位最高出价者
            _refundBid(auction);
        }
        
        auction.highestBidder = msg.sender;
        auction.highestBid = currentBid;
        auction.bidType = BidType.ETH;
        auction.bidToken = address(0);
        
        emit BidPlaced(
            auctionId,
            msg.sender,
            currentBid,
            BidType.ETH,
            address(0),
            currentBidUSD
        );
    }
    
    /**
     * @notice 使用 ERC20 代币出价
     * @param auctionId 拍卖 ID
     * @param token ERC20 代币地址
     * @param amount 代币数量
     */
    function bidWithERC20(
        uint256 auctionId,
        address token,
        uint256 amount
    ) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction not found");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(!auction.settled, "Auction settled");
        require(token != address(0), "Invalid token address");
        require(address(tokenPriceFeeds[token]) != address(0), "Token price feed not set");
        
        // 转移代币到合约
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        uint256 currentBidUSD = tokenToUSD(token, amount);
        
        // 检查是否满足最低出价要求
        require(currentBidUSD >= auction.minBidUSD, "Bid below minimum");
        
        // 如果已有出价，检查是否高于当前最高价
        if (auction.highestBidder != address(0)) {
            uint256 highestBidUSD = _getBidUSDValue(
                auction.highestBid,
                auction.bidType,
                auction.bidToken
            );
            require(currentBidUSD > highestBidUSD, "Bid too low");
            
            // 退还上一位最高出价者
            _refundBid(auction);
        }
        
        auction.highestBidder = msg.sender;
        auction.highestBid = amount;
        auction.bidType = BidType.ERC20;
        auction.bidToken = token;
        
        emit BidPlaced(
            auctionId,
            msg.sender,
            amount,
            BidType.ERC20,
            token,
            currentBidUSD
        );
    }
    
    /**
     * @notice 结束拍卖：转移 NFT 和资金
     * @param auctionId 拍卖 ID
     */
    function endAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction not found");
        require(block.timestamp >= auction.endTime, "Auction not yet ended");
        require(!auction.settled, "Already settled");
        
        auction.settled = true;
        
        if (auction.highestBidder != address(0)) {
            // 有人出价：NFT -> 最高出价者，资金 -> 卖家
            IERC721(auction.nftAddress).transferFrom(
                address(this),
                auction.highestBidder,
                auction.tokenId
            );
            
            _payoutSeller(auction);
            
            emit AuctionSettled(
                auctionId,
                auction.seller,
                auction.highestBidder,
                auction.highestBid,
                auction.bidType,
                auction.bidToken
            );
        } else {
            // 无人出价：NFT 退回给卖家
            IERC721(auction.nftAddress).transferFrom(
                address(this),
                auction.seller,
                auction.tokenId
            );
            
            emit AuctionSettled(
                auctionId,
                auction.seller,
                address(0),
                0,
                BidType.ETH,
                address(0)
            );
        }
    }
    
    // ============ 查询功能 ============
    
    /**
     * @notice 获取拍卖的当前最高出价（美元）
     * @param auctionId 拍卖 ID
     * @return usdValue 美元价值（18 位小数）
     */
    function getAuctionHighestBidUSD(uint256 auctionId)
        public
        view
        returns (uint256 usdValue)
    {
        Auction memory auction = auctions[auctionId];
        if (auction.highestBidder == address(0)) {
            return 0;
        }
        return _getBidUSDValue(auction.highestBid, auction.bidType, auction.bidToken);
    }
    
    /**
     * @notice 获取出价的美元价值（内部函数）
     */
    function _getBidUSDValue(
        uint256 amount,
        BidType bidType,
        address token
    ) internal view returns (uint256) {
        if (bidType == BidType.ETH) {
            return ethToUSD(amount);
        } else {
            return tokenToUSD(token, amount);
        }
    }
    
    /**
     * @notice 退还出价（内部函数）
     */
    function _refundBid(Auction storage auction) internal {
        if (auction.bidType == BidType.ETH) {
            (bool refundOk, ) = auction.highestBidder.call{
                value: auction.highestBid
            }("");
            require(refundOk, "ETH refund failed");
        } else {
            IERC20(auction.bidToken).transfer(auction.highestBidder, auction.highestBid);
        }
    }
    
    /**
     * @notice 支付卖家（内部函数）
     */
    function _payoutSeller(Auction storage auction) internal {
        if (auction.bidType == BidType.ETH) {
            (bool payoutOk, ) = auction.seller.call{
                value: auction.highestBid
            }("");
            require(payoutOk, "ETH payout failed");
        } else {
            IERC20(auction.bidToken).transfer(auction.seller, auction.highestBid);
        }
    }
}

