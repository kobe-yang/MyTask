// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MyNFT721} from "../src/MyNFT721.sol";

contract DeployMyNFT721 is Script {
    function run() external returns (MyNFT721) {
        vm.startBroadcast();
        MyNFT721 nft = new MyNFT721();
        vm.stopBroadcast();
        return nft;
    }
}

