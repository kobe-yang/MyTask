// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {SimpleNFT} from "../src/SimpleNFT.sol";

contract SimpleNFTTest is Test {
    SimpleNFT internal nft;
    address internal owner = address(this);
    address internal alice = address(0x1);

    function setUp() public {
        nft = new SimpleNFT("SimpleNFT", "SNFT");
    }

    function testMintOnlyOwner() public {
        string memory uri = "ipfs://token/1";
        uint256 tokenId = nft.mint(alice, uri);

        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.tokenURI(tokenId), uri);

        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        nft.mint(alice, "ipfs://token/2");
    }

    function testTokenIdIncrements() public {
        uint256 id1 = nft.mint(alice, "uri1");
        uint256 id2 = nft.mint(alice, "uri2");

        assertEq(id1, 0);
        assertEq(id2, 1);
    }
}


