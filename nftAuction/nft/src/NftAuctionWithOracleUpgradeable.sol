// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "openzeppelin/contracts/token/ERC721/IERC721.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./libraries/PriceOracleLib.sol";

/**
 * @title NftAuctionWithOracleUpgradeable
 * @notice 可升级的 NFT 拍卖合约（UUPS 代理模式）
 * @dev 支持 ETH 和 ERC20 代币出价，自动转换为美元价值
 *  Implementation deployed at: 0x53430EA8d0b2b9673eda74119329A4Ab3286d3EA
 *  Proxy deployed at: 0xB8BbC68e2f18304c4e8C77481E90164CBa17428A
 */
contract NftAuctionWithOracleUpgradeable is 
    Initializable, 
    UUPSUpgradeable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    using PriceOracleLib for AggregatorV3Interface;
    
    // ============ 价格预言机相关 ============
    
    AggregatorV3Interface public ethUsdPriceFeed;
    mapping(address => AggregatorV3Interface) public tokenPriceFeeds;
    uint256 public stalePriceThreshold;
    
    // ============ 拍卖相关 ============
    
    enum BidType { ETH, ERC20 }
    
    struct Auction {
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 minBidUSD;
        uint256 endTime;
        address highestBidder;
        uint256 highestBid;
        BidType bidType;
        address bidToken;
        bool settled;
    }
    
    uint256 public nextAuctionId;
    mapping(uint256 => Auction) public auctions;
    
    // ============ 版本控制 ============
    
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    uint256 public constant VERSION = 1;
    
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
    
    // ============ 初始化（替代构造函数） ============
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @notice 初始化函数（只能调用一次）
     * @param _ethUsdPriceFeed ETH/USD 价格聚合器地址
     * @param _owner 合约所有者
     */
    function initialize(address _ethUsdPriceFeed, address _owner) public initializer {
        require(_ethUsdPriceFeed != address(0), "Invalid price feed");
        require(_owner != address(0), "Invalid owner");
        
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        stalePriceThreshold = 3600 * 24; // 24 小时
    }
    
    // ============ UUPS 升级授权 ============
    
    /**
     * @notice 授权合约升级（仅限 owner）
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // ============ 价格预言机功能 ============
    
    function setTokenPriceFeed(address token, address priceFeed) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(priceFeed != address(0), "Invalid price feed");
        tokenPriceFeeds[token] = AggregatorV3Interface(priceFeed);
        emit PriceFeedUpdated(token, priceFeed);
    }
    
    function setStalePriceThreshold(uint256 _threshold) external onlyOwner {
        uint256 oldThreshold = stalePriceThreshold;
        stalePriceThreshold = _threshold;
        emit StalePriceThresholdUpdated(oldThreshold, _threshold);
    }
    
    function getEthPriceInUSD() public view returns (uint256) {
        return ethUsdPriceFeed.getPriceInUSD(stalePriceThreshold);
    }
    
    function getTokenPriceInUSD(address token) public view returns (uint256) {
        AggregatorV3Interface priceFeed = tokenPriceFeeds[token];
        require(address(priceFeed) != address(0), "Token price feed not set");
        return priceFeed.getPriceInUSD(stalePriceThreshold);
    }
    
    function ethToUSD(uint256 ethAmount) public view returns (uint256) {
        uint256 ethPrice = getEthPriceInUSD();
        return PriceOracleLib.ethToUSD(ethAmount, ethPrice);
    }
    
    function tokenToUSD(address token, uint256 tokenAmount) public view returns (uint256) {
        uint256 tokenPrice = getTokenPriceInUSD(token);
        return PriceOracleLib.tokenToUSD(tokenAmount, tokenPrice);
    }
    
    // ============ 拍卖功能 ============
    
    function createAuction(
        address nftAddress,
        uint256 tokenId,
        uint256 minBidUSD,
        uint256 duration
    ) external returns (uint256 auctionId) {
        require(duration > 0, "Duration must be > 0");
        require(minBidUSD > 0, "Min bid must be > 0");
        
        auctionId = nextAuctionId++;
        IERC721(nftAddress).transferFrom(msg.sender, address(this), tokenId);
        
        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftAddress: nftAddress,
            tokenId: tokenId,
            minBidUSD: minBidUSD,
            endTime: block.timestamp + duration,
            highestBidder: address(0),
            highestBid: 0,
            bidType: BidType.ETH,
            bidToken: address(0),
            settled: false
        });
        
        emit AuctionCreated(auctionId, msg.sender, nftAddress, tokenId, minBidUSD, block.timestamp + duration);
    }
    
    function bidWithETH(uint256 auctionId) external payable nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction not found");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(!auction.settled, "Auction settled");
        
        uint256 currentBidUSD = ethToUSD(msg.value);
        require(currentBidUSD >= auction.minBidUSD, "Bid below minimum");
        
        if (auction.highestBidder != address(0)) {
            uint256 highestBidUSD = _getBidUSDValue(auction.highestBid, auction.bidType, auction.bidToken);
            require(currentBidUSD > highestBidUSD, "Bid too low");
            _refundBid(auction);
        }
        
        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
        auction.bidType = BidType.ETH;
        auction.bidToken = address(0);
        
        emit BidPlaced(auctionId, msg.sender, msg.value, BidType.ETH, address(0), currentBidUSD);
    }
    
    function bidWithERC20(uint256 auctionId, address token, uint256 amount) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction not found");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(!auction.settled, "Auction settled");
        require(address(tokenPriceFeeds[token]) != address(0), "Token price feed not set");
        
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        uint256 currentBidUSD = tokenToUSD(token, amount);
        require(currentBidUSD >= auction.minBidUSD, "Bid below minimum");
        
        if (auction.highestBidder != address(0)) {
            uint256 highestBidUSD = _getBidUSDValue(auction.highestBid, auction.bidType, auction.bidToken);
            require(currentBidUSD > highestBidUSD, "Bid too low");
            _refundBid(auction);
        }
        
        auction.highestBidder = msg.sender;
        auction.highestBid = amount;
        auction.bidType = BidType.ERC20;
        auction.bidToken = token;
        
        emit BidPlaced(auctionId, msg.sender, amount, BidType.ERC20, token, currentBidUSD);
    }
    
    function endAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction not found");
        require(block.timestamp >= auction.endTime, "Auction not yet ended");
        require(!auction.settled, "Already settled");
        
        auction.settled = true;
        
        if (auction.highestBidder != address(0)) {
            IERC721(auction.nftAddress).transferFrom(address(this), auction.highestBidder, auction.tokenId);
            _payoutSeller(auction);
            emit AuctionSettled(auctionId, auction.seller, auction.highestBidder, auction.highestBid, auction.bidType, auction.bidToken);
        } else {
            IERC721(auction.nftAddress).transferFrom(address(this), auction.seller, auction.tokenId);
            emit AuctionSettled(auctionId, auction.seller, address(0), 0, BidType.ETH, address(0));
        }
    }
    
    // ============ 内部函数 ============
    
    function _getBidUSDValue(uint256 amount, BidType bidType, address token) internal view returns (uint256) {
        return bidType == BidType.ETH ? ethToUSD(amount) : tokenToUSD(token, amount);
    }
    
    function _refundBid(Auction storage auction) internal {
        if (auction.bidType == BidType.ETH) {
            (bool ok, ) = auction.highestBidder.call{value: auction.highestBid}("");
            require(ok, "ETH refund failed");
        } else {
            IERC20(auction.bidToken).transfer(auction.highestBidder, auction.highestBid);
        }
    }
    
    function _payoutSeller(Auction storage auction) internal {
        if (auction.bidType == BidType.ETH) {
            (bool ok, ) = auction.seller.call{value: auction.highestBid}("");
            require(ok, "ETH payout failed");
        } else {
            IERC20(auction.bidToken).transfer(auction.seller, auction.highestBid);
        }
    }
    
    function getAuctionHighestBidUSD(uint256 auctionId) public view returns (uint256) {
        Auction memory auction = auctions[auctionId];
        return auction.highestBidder == address(0) ? 0 : _getBidUSDValue(auction.highestBid, auction.bidType, auction.bidToken);
    }
}

