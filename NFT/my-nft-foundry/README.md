# MyNFT721 (Foundry)

最简 Foundry ERC721 项目（已删除 Hardhat 脚手架，只保留 Foundry 所需文件）。

## 目录结构
```
my-nft-foundry/
├── foundry.toml          # Foundry 配置
├── lib/                  # 依赖（运行 forge install 后出现）
├── src/
│   └── MyNFT721.sol      # ERC721 合约
├── script/
│   └── DeployMyNFT721.s.sol  # 部署脚本
├── out/ cache/ broadcast/    # 编译/部署产物（执行命令后生成）
```

## 步骤（工作流示例）

1) 安装 Foundry（如未安装）
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2) 安装依赖（OpenZeppelin）
```bash
cd task/third/my-nft-foundry
# 若网络有 HTTP/2 问题，可先：
# git config --global http.version HTTP/1.1
GIT_HTTP_VERSION=HTTP/1.1 forge install OpenZeppelin/openzeppelin-contracts
```

3) 编译
```bash
forge build
```

4) 本地部署（Anvil）
```bash
# 终端1：启动本地节点
anvil

# 终端2：部署
forge script script/DeployMyNFT721.s.sol:DeployMyNFT721 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast \
  -vvvv
```

5) 可选：Sepolia 部署
```bash
export SEPOLIA_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/<your_key>"
export SEPOLIA_PRIVATE_KEY="0x<your_private_key>"
forge script script/DeployMyNFT721.s.sol:DeployMyNFT721 \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --private-key "$SEPOLIA_PRIVATE_KEY" \
  --broadcast \
  -vvvv
```

6) 铸造示例（Cast）
```bash
cast send 0xYourContractAddress \
  "mint(address,string)" \
  0xYourWalletAddress \
  "ipfs://QmMetadata..." \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

## 合约简介
`src/MyNFT721.sol` 基于 OpenZeppelin：
- 继承 `ERC721URIStorage` 与 `Ownable`
- 自增 `_nextTokenId`
- `mint(address to, string tokenURI_)` 仅 owner 可调用，设置 `tokenURI`

## FAQ
- 如果 `forge install` 出现 HTTP/2 framing 错误，按上面步骤切换 HTTP/1.1 再试。
- 删除的 Hardhat 文件：`hardhat.config.ts`、`package.json`、`tsconfig.json`、`scripts/`、`contracts/Counter*` 等，已不再使用。
