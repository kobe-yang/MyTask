// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "openzeppelin/contracts/access/Ownable.sol";

contract SimpleNFT is ERC721URIStorage, Ownable {

    uint256 private _nextTokenId;

    constructor(string name,string ) ERC721("SimpleNFT", "SNFT") Ownable(msg.sender) {}

    function mint(address to, string memory tokenURI) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        return tokenId;
    }
}