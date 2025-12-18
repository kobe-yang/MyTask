# 第三个任务：使用 OpenZeppelin 实现 ERC721 NFT（Foundry 版）

本任务基于 **Foundry**（不再使用 Hardhat），完成一个 OpenZeppelin ERC721 NFT：
1) 改写 `MYNFT.sol` 为 ERC721（OpenZeppelin）
2) IPFS 上传图片与元数据，获得 `tokenURI`
3) 本地 Anvil 部署与测试；可选部署到 Sepolia
4) 铸造 NFT 并在浏览器 / OpenSea Testnet 查看

---

## 目录结构（forge init 默认生成）

```
task/third/
├── MYNFT.sol             # 你的任务合约（待改造成 ERC721）
├── README.md             # 任务说明（本文件）
└── my-project/           # 如你在此目录下 forge init，将生成：
    ├── foundry.toml      # Foundry 配置
    ├── lib/              # 依赖（例如 forge-std、openzeppelin-contracts）
    ├── src/              # 合约源码，默认有 Counter.sol，可删或替换
    ├── script/           # 部署脚本，默认 Counter.s.sol，可删或替换
    ├── test/             # 测试，默认 Counter.t.sol，可删或替换
    ├── out/、cache/      # 编译产物与缓存
    └── broadcast/        # 部署广播记录
```

## 安装问题

forge install 克隆 OZ 时被代理/网络劫持导致 HTTP/2 framing 错误。浏览器能打开，但 git 走 HTTP/2 被中间层干扰。绕过方法：
1) 切到正确项目目录（例如 Foundry 项目根）：
   openzeppelin-contracts
   cd /Users/kobeyang/Desktop/web3/solidity/task/third/my-project   # 按你的实际项目路径rm -rf lib/openzeppelin-contracts  # 清掉失败的残留
2) 让 git 走 HTTP/1.1 再试：
   forge install OpenZeppelin/openzeppelin-contracts --no-commit
   git config --global http.version HTTP/1.1GIT_HTTP_VERSION=HTTP/1.1 forge install OpenZeppelin/openzeppelin-contracts --no-commit
   如果还有问题，可再加：
   git config --global http.postBuffer 524288000git config --global http.lowSpeedLimit 0git config --global http.lowSpeedTime 999999
   然后重试 forge install ...。这样能避开 HTTP/2 代理/网络的兼容问


> 默认的 Counter 示例、脚本、测试不是必须的：可以删除或直接用 `MYNFT` 覆盖它们（保持文件名/引用一致即可）。

---

## 环境准备（Foundry）

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
forge --version
```

初始化项目（示例放在 `task/third/my-project`）：
```bash
cd task/third
forge init my-project
cd my-project
```

安装 OpenZeppelin：
```bash
forge install OpenZeppelin/openzeppelin-contracts
```

确保 `foundry.toml` 的 libs 包含 `lib`（默认如此）：
```toml
[profile.default]
libs = ["lib"]
```

---

## 编写 ERC721 合约（修改 `task/third/MYNFT.sol`）

示例结构（可直接参考修改）：
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract MYNFT is ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    constructor() ERC721("My NFT", "MYNFT") Ownable(msg.sender) {}

    function mint(address to, string memory tokenURI_) external onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI_);
        return tokenId;
    }
}
```

> 你可以将 `my-project/src/Counter.sol` 替换为上述内容（或直接把 `MYNFT.sol` 放进 `src/`，记得更新脚本/测试的合约名）。

---

## IPFS 准备

> 无论你把合约部署在本地 Anvil、Sepolia 还是主网，**IPFS 的用法都是一样的**：  
> 先把图片上传到 IPFS，再把 `metadata.json` 上传到 IPFS，最终在合约里只需要一个 `ipfs://...` 作为 `tokenURI`。

### 1) 使用网站上传（推荐）

- **Pinata**：`https://pinata.cloud/`  
  1. 注册并登录  
  2. 顶部导航选择 **Upload → File**，上传图片，得到图片 CID，例如：  
     `ipfs://QmImageCid123...`  
  3. 本地创建 `metadata.json`：
     ```json
     {
       "name": "My First NFT",
       "description": "This is my first ERC721 NFT on Sepolia.",
       "image": "ipfs://QmImageCid123...",
       "attributes": [
         { "trait_type": "Level", "value": 1 }
       ]
     }
     ```
  4. 再把 `metadata.json` 上传到 Pinata，得到元数据 CID：  
     `ipfs://QmMetadataCid456...`

- **NFT.Storage**：`https://nft.storage/`  
  - 注册后在 Dashboard 中上传图片和 `metadata.json`，流程与 Pinata 类似，最终也会得到一个 `ipfs://<cid>`。

- **Web3.Storage**：`https://web3.storage/`  
  - 同样是注册 → 上传文件 → 获得 CID。

> 以上任意一个平台都可用，得到的 `ipfs://<cid>` 链接都可以直接作为 `tokenURI`。

### 2) 使用本地 IPFS（可选）

- 安装 IPFS Desktop：`https://docs.ipfs.tech/install/ipfs-desktop/`  
- 启动后在 UI 中选择 **Files → Import → File/Folder**，上传图片与 `metadata.json`  
- 每个文件会得到一个 CID，例如：`QmLocalCid...`，一样使用 `ipfs://QmLocalCid...`

### 3) 在 Sepolia 合约中如何使用

假设你已经拿到：

- 图片 CID：`ipfs://QmImageCid123...`
- 元数据 CID：`ipfs://QmMetadataCid456...`

在 `MyNFT721` 或 `MYNFT` 合约中调用 `mint` 时：

```solidity
myNft.mint(
    0xYourSepoliaAddress,
    "ipfs://QmMetadataCid456..." // 这里就是上传 metadata 后得到的 CID
);
```

> 区分：**Sepolia 只是你发送交易和查 NFT 的链；NFT 内容本身是存放在 IPFS 网络中的，通过 `ipfs://...` 链接访问。**

---

## 部署脚本（Foundry）

创建 `script/DeployMYNFT.s.sol`（放在 `my-project/script/`）：
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MYNFT} from "../src/MYNFT.sol";

contract DeployMYNFT is Script {
    function run() external returns (MYNFT) {
        vm.startBroadcast();
        MYNFT myNft = new MYNFT();
        vm.stopBroadcast();
        return myNft;
    }
}
```

---

## 本地部署（Anvil）

```bash
# 终端 1：启动本地节点
anvil  # http://127.0.0.1:8545

# 终端 2：部署
cd task/third/my-project
forge script script/DeployMyNFT721.s.sol:DeployMyNFT721 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast \
  -vvvv
```

---

## 可选：部署到 Sepolia

```bash
export SEPOLIA_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/<your_key>"
export SEPOLIA_PRIVATE_KEY="0x<your_private_key>"

forge script script/DeployMyNFT721.s.sol:DeployMyNFT721 \
  --root /Users/kobeyang/Desktop/web3/solidity/task/third/my-nft-foundry \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --private-key "$SEPOLIA_PRIVATE_KEY" \
  --broadcast \
  -vvvv
  
单独验证合约

forge verify-contract 0x0abA560dd5a29AD449b5654c8F4fcdd1E408113C \
  src/MyNFT721.sol:MyNFT721 \
  --chain sepolia \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  -vvvv  
  
```

> 若需要验证，可加 `--verify --etherscan-api-key <KEY>`（Etherscan Key 需支持 Sepolia）。

---

## 铸造与查看

使用 Cast：
```bash
cast send 0x0abA560dd5a29AD449b5654c8F4fcdd1E408113C \
  "mint(address,string)" \
  0xfab857c5a4c3047abeed3f5c044f871b8633649d \
  "ipfs://bafybeigne3wjzxtkwbkcmpaq4gieffw7c4bulfn3opwpktemti4v5q4454" \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --private-key "$SEPOLIA_PRIVATE_KEY" 
```

在浏览器查看：
- 本地：通过前端/脚本读取 `tokenURI`/`ownerOf`
- Sepolia：在 Etherscan Sepolia 或 OpenSea Testnet 查看合约与 NFT

---

## FAQ：默认合约要不要删？
- forge 初始化生成的 `Counter.sol` / `Counter.s.sol` / `Counter.t.sol` 只是示例，可以删除，也可以直接用 `MYNFT` 覆盖（记得同步脚本和测试里的合约名）。
- 删除后记得更新部署脚本路径与合约名，以免 `forge script` 找不到目标。

---

## 任务 Checklist
- [ ] `MYNFT.sol` 基于 OpenZeppelin ERC721 完成
- [ ] IPFS 图片与元数据上传，拿到 `ipfs://...` 作为 `tokenURI`
- [ ] 本地 Anvil 成功部署并可铸造
- [ ] （可选）Sepolia 部署并验证
- [ ] 在浏览器 / OpenSea Testnet 能看到铸造结果

完成以上即可提交任务。建议把最终合约地址、`tokenURI`、铸造交易哈希等记录在本文件下方，方便回溯。

---

## 实战：`my-nft-foundry` 目录（Foundry 项目，用于交付 MyNFT721）

### 目录结构
```
my-nft-foundry/
├── foundry.toml
├── src/
│   └── MyNFT721.sol
├── script/
│   └── DeployMyNFT721.s.sol
├── lib/ (运行 forge install 后出现)
└── out/ cache/ broadcast/ (执行编译/部署后生成)
```

### 1) 安装依赖
```bash
cd task/third/my-nft-foundry
# 如遇 HTTP/2 问题，可先：
# git config --global http.version HTTP/1.1
GIT_HTTP_VERSION=HTTP/1.1 forge install OpenZeppelin/openzeppelin-contracts
```

### 2) 编译
```bash
forge build
```

### 3) 本地部署（Anvil）
```bash
# 终端1
anvil

# 终端2
forge script script/DeployMyNFT721.s.sol:DeployMyNFT721 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast \
  -vvvv
```

### 4) 可选：Sepolia 部署
```bash
export SEPOLIA_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/<your_key>"
export SEPOLIA_PRIVATE_KEY="0x<your_private_key>"
forge script script/DeployMyNFT721.s.sol:DeployMyNFT721 \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --private-key "$SEPOLIA_PRIVATE_KEY" \
  --broadcast \
  -vvvv
```

### 5) 铸造示例（Cast）
```bash
cast send 0xYourContractAddress \
  "mint(address,string)" \
  0xYourWalletAddress \
  "ipfs://QmMetadata..." \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

