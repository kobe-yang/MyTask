// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./NftAuctionWithOracleUpgradeable.sol";

/**
 * @title NftAuctionWithOracleUpgradeableV2
 * @notice V2 版本：新增修改拍卖结束时间功能
 * @dev 继承 V1，只添加新功能
   Proxy (unchanged): 0xB8BbC68e2f18304c4e8C77481E90164CBa17428A
  New Implementation: 0x8180A719a5ba26D75B5f288b9Eed43fB6BDcFFa0
  NEW_PROXY: 0x8180A719a5ba26D75B5f288b9Eed43fB6BDcFFa0
 */
contract NftAuctionWithOracleUpgradeableV2 is NftAuctionWithOracleUpgradeable {
    
    // ============ 版本更新 ============
    uint256 public constant VERSION_V2 = 2;
    
    // ============ V2 新增事件 ============
    event AuctionTimeChanged(
        uint256 indexed auctionId,
        uint256 oldEndTime,
        uint256 newEndTime
    );
    
    // ============ V2 新增功能 ============
    
    /**
     * @notice 修改拍卖结束时间（仅卖家可调用）
     * @param auctionId 拍卖 ID
     * @param newEndTime 新的结束时间戳
     */
    function setAuctionEndTime(uint256 auctionId, uint256 newEndTime) external {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction not found");
        require(msg.sender == auction.seller, "Only seller");
        require(!auction.settled, "Already settled");
        require(newEndTime > block.timestamp, "Must be in future");
        
        uint256 oldEndTime = auction.endTime;
        auction.endTime = newEndTime;
        
        emit AuctionTimeChanged(auctionId, oldEndTime, newEndTime);
    }
    
    /**
     * @notice 取消拍卖（仅卖家，无人出价时）
     * @param auctionId 拍卖 ID
     */
    function cancelAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.seller != address(0), "Auction not found");
        require(msg.sender == auction.seller, "Only seller");
        require(!auction.settled, "Already settled");
        require(auction.highestBidder == address(0), "Has bids");
        
        auction.settled = true;
        IERC721(auction.nftAddress).transferFrom(address(this), auction.seller, auction.tokenId);
        
        emit AuctionSettled(auctionId, auction.seller, address(0), 0, BidType.ETH, address(0));
    }
    
    /**
     * @notice 获取版本号
     */
    function getVersion() external pure returns (uint256) {
        return VERSION_V2;
    }
}
