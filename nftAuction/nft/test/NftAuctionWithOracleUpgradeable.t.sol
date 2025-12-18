// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NftAuctionWithOracleUpgradeable} from "../src/NftAuctionWithOracleUpgradeable.sol";
import {SimpleNFT} from "../src/SimpleNFT.sol";
import {SimpleToken} from "../src/SimpleToken.sol";
import {MockPriceFeed} from "../src/mocks/MockPriceFeed.sol";

contract NftAuctionWithOracleUpgradeableTest is Test {
    NftAuctionWithOracleUpgradeable internal auction;
    SimpleNFT internal nft;
    SimpleToken internal erc20;
    MockPriceFeed internal ethFeed;
    MockPriceFeed internal tokenFeed;

    address internal seller = address(0x1);
    address internal bidderEth = address(0x2);
    address internal bidderErc20 = address(0x3);

    uint256 internal constant INITIAL_ETH_PRICE = 2_000e8; // $2000
    uint256 internal constant INITIAL_TOKEN_PRICE = 1e8;   // $1

    function setUp() public {
        // deploy mocks and tokens
        ethFeed = new MockPriceFeed(int256(INITIAL_ETH_PRICE), "ETH / USD");
        tokenFeed = new MockPriceFeed(int256(INITIAL_TOKEN_PRICE), "TKN / USD");

        nft = new SimpleNFT("SimpleNFT", "SNFT");
        erc20 = new SimpleToken("SimpleToken", "STK", 0);

        // deploy implementation + UUPS proxy, since implementation constructor disables initializers
        NftAuctionWithOracleUpgradeable impl = new NftAuctionWithOracleUpgradeable();
        bytes memory initData = abi.encodeWithSelector(
            NftAuctionWithOracleUpgradeable.initialize.selector,
            address(ethFeed),
            address(this)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        auction = NftAuctionWithOracleUpgradeable(address(proxy));

        auction.setTokenPriceFeed(address(erc20), address(tokenFeed));

        // prepare balances
        vm.deal(bidderEth, 100 ether);
        erc20.mint(bidderErc20, 10_000e18);
    }

    function _createAuction() internal returns (uint256 auctionId, uint256 tokenId) {
        // mint NFT to seller and approve auction contract
        tokenId = nft.mint(seller, "ipfs://nft");
        vm.prank(seller);
        nft.approve(address(auction), tokenId);

        vm.prank(seller);
        auctionId = auction.createAuction(address(nft), tokenId, 1_000e18, 1 days); // min $1000
    }

    function testCreateAuctionTransfersNFT() public {
        (uint256 auctionId, uint256 tokenId) = _createAuction();
        assertEq(auctionId, 0);
        assertEq(nft.ownerOf(tokenId), address(auction));
    }

    function testBidWithEthAboveMin() public {
        (uint256 auctionId, ) = _createAuction();

        // $2000/ETH, minBidUSD=1000 => need at least 0.5 ETH
        vm.prank(bidderEth);
        auction.bidWithETH{value: 0.6 ether}(auctionId);

        (
            ,
            ,
            ,
            ,
            ,
            address highestBidder,
            ,
            NftAuctionWithOracleUpgradeable.BidType bidType,
            address _ignoredToken,
            bool _ignoredSettled
        ) = auction.auctions(auctionId);

        assertEq(highestBidder, bidderEth);
        assertEq(uint8(bidType), uint8(NftAuctionWithOracleUpgradeable.BidType.ETH));
    }

    function testBidWithEthBelowMinReverts() public {
        (uint256 auctionId, ) = _createAuction();

        vm.prank(bidderEth);
        vm.expectRevert("Bid below minimum");
        auction.bidWithETH{value: 0.1 ether}(auctionId);
    }

    function testBidWithErc20AndOutbidEth() public {
        (uint256 auctionId, ) = _createAuction();

        // first bidder with ETH
        vm.prank(bidderEth);
        auction.bidWithETH{value: 0.6 ether}(auctionId); // ~$1200

        // second bidder with ERC20, price $1, need >1200 tokens
        vm.startPrank(bidderErc20);
        erc20.approve(address(auction), type(uint256).max);
        auction.bidWithERC20(auctionId, address(erc20), 1_500e18);
        vm.stopPrank();

        (
            ,
            ,
            ,
            ,
            ,
            address highestBidder,
            ,
            NftAuctionWithOracleUpgradeable.BidType bidType,
            address bidToken,
            bool _ignoredSettled
        ) = auction.auctions(auctionId);

        assertEq(highestBidder, bidderErc20);
        assertEq(uint8(bidType), uint8(NftAuctionWithOracleUpgradeable.BidType.ERC20));
        assertEq(bidToken, address(erc20));
    }

    function testEndAuctionTransfersToWinnerAndPaysSeller() public {
        (uint256 auctionId, uint256 tokenId) = _createAuction();

        uint256 sellerEthBefore = seller.balance;

        // winner with ETH
        vm.prank(bidderEth);
        auction.bidWithETH{value: 1 ether}(auctionId); // $2000

        // fast-forward past endTime
        vm.warp(block.timestamp + 2 days);

        vm.prank(bidderEth);
        auction.endAuction(auctionId);

        // NFT to highest bidder
        assertEq(nft.ownerOf(tokenId), bidderEth);

        // seller received ETH
        assertEq(seller.balance, sellerEthBefore + 1 ether);
    }
}


