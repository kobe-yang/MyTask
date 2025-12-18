// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin/contracts/token/ERC721/IERC721.sol";
import "openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SimpleNftAuction is ReentrancyGuard {
    struct Auction {
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 minBid;        // 起拍价
        uint256 endTime;       // 结束时间（时间戳）
        address highestBidder; // 当前最高出价者
        uint256 highestBid;    // 当前最高出价
        bool settled;          // 是否已结算
    }

    uint256 public nextAuctionId;
    mapping(uint256 => Auction) public auctions;

    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 minBid,
        uint256 endTime
    );

    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );

    event AuctionSettled(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed winner,
        uint256 amount
    );

    /// @notice 创建拍卖（NFT 需要提前 approve 给本合约）
    function createAuction(
        address nftAddress,
        uint256 tokenId,
        uint256 minBid,
        uint256 duration
    ) external returns (uint256 auctionId) {
        require(duration > 0, "Duration must be > 0");

        auctionId = nextAuctionId++;

        // 将 NFT 从卖家转移到拍卖合约托管
        IERC721(nftAddress).transferFrom(msg.sender, address(this), tokenId);

        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftAddress: nftAddress,
            tokenId: tokenId,
            minBid: minBid,
            endTime: block.timestamp + duration,
            highestBidder: address(0),
            highestBid: 0,
            settled: false
        });

        emit AuctionCreated(
            auctionId,
            msg.sender,
            nftAddress,
            tokenId,
            minBid,
            block.timestamp + duration
        );
    }

    /// @notice 出价（使用原生 ETH），必须高于当前最高价
    function bid(uint256 auctionId) external payable nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction not found");
        require(block.timestamp < auction.endTime, "Auction ended");

        uint256 currentBid = msg.value;
        require(
            currentBid >= auction.minBid &&
                currentBid > auction.highestBid,
            "Bid too low"
        );

        // 退还上一位最高出价者
        if (auction.highestBidder != address(0)) {
            (bool refundOk, ) = auction.highestBidder.call{
                value: auction.highestBid
            }("");
            require(refundOk, "Refund failed");
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = currentBid;

        emit BidPlaced(auctionId, msg.sender, currentBid);
    }

    /// @notice 结束拍卖：转移 NFT 和 ETH
    function endAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction not found");
        require(block.timestamp >= auction.endTime, "Auction not yet ended");
        require(!auction.settled, "Already settled");

        auction.settled = true;

        if (auction.highestBidder != address(0)) {
            // 有人出价：NFT -> 最高出价者，ETH -> 卖家
            IERC721(auction.nftAddress).transferFrom(
                address(this),
                auction.highestBidder,
                auction.tokenId
            );

            (bool payoutOk, ) = auction.seller.call{
                value: auction.highestBid
            }("");
            require(payoutOk, "Payout failed");

            emit AuctionSettled(
                auctionId,
                auction.seller,
                auction.highestBidder,
                auction.highestBid
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
                0
            );
        }
    }
}