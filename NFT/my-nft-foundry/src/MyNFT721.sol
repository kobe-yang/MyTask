// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "openzeppelin/contracts/access/Ownable.sol";

/// @title MyNFT721 - Simple ERC721 with owner-only mint and tokenURI storage
contract MyNFT721 is ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    constructor() ERC721("My NFT 721", "MYNFT") Ownable(msg.sender) {}

    function mint(address to, string memory tokenURI_) external onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI_);
        return tokenId;
    }
}

