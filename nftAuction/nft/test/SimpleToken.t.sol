// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Ownable} from "openzeppelin/contracts/access/Ownable.sol";
import {SimpleToken} from "../src/SimpleToken.sol";

contract SimpleTokenTest is Test {
    SimpleToken internal token;
    address internal owner = address(this);
    address internal alice = address(0x1);

    function setUp() public {
        // name, symbol, initialSupply = 1_000_000
        token = new SimpleToken("SimpleToken", "STK", 1_000_000);
    }

    function testInitialSupplyMintedToOwner() public {
        uint256 expected = 1_000_000 * 10 ** token.decimals();
        assertEq(token.totalSupply(), expected);
        assertEq(token.balanceOf(owner), expected);
    }

    function testOnlyOwnerCanMint() public {
        uint256 amount = 100e18;
        token.mint(alice, amount);
        assertEq(token.balanceOf(alice), amount);

        vm.prank(alice);
        // 只要非 owner 调用会 revert 即可，这里不强绑定具体错误编码
        vm.expectRevert();
        token.mint(alice, amount);
    }

    function testBurnReducesSupply() public {
        uint256 burnAmount = 50e18;
        uint256 initialSupply = token.totalSupply();
        token.burn(burnAmount);

        assertEq(token.totalSupply(), initialSupply - burnAmount);
        assertEq(token.balanceOf(owner), initialSupply - burnAmount);
    }
}


