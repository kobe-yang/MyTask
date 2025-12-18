#!/bin/bash

# ============================================================
# NftAuctionWithOracleUpgradeable 交互脚本
# ============================================================

# ============ 环境变量配置 ============
export PRIVATE_KEY="你的私钥"
export SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_ID"

# 合约地址
export PROXY_ADDRESS="0xB8BbC68e2f18304c4e8C77481E90164CBa17428A"  # 拍卖合约代理地址
export TOKEN_ADDRESS="0xf4AF69986484E9847F848F5c4F8686D62EBC9102"  # SimpleToken 地址
export NFT_ADDRESS="你的NFT合约地址"  # SimpleNFT 地址

# 你的钱包地址
export MY_ADDRESS="0xfab857c5a4c3047abeed3F5c044f871b8633649d"

# ============================================================
# 步骤 1: 部署 MockPriceFeed 并关联代币
# ============================================================

echo "========== 步骤 1: 关联代币到价格预言机 =========="

# 1.1 先部署一个 MockPriceFeed（如果还没有）
# 设置初始价格为 $1.5 USD (1.5 * 10^8 = 150000000)
export INITIAL_PRICE=150000000
export PRICE_DESCRIPTION="STK/USD"

echo "部署 MockPriceFeed..."
# forge script script/DeployMockPriceFeed.s.sol:DeployMockPriceFeed \
#   --rpc-url $SEPOLIA_RPC_URL \
#   --private-key $PRIVATE_KEY \
#   --broadcast -vvvv

# 假设部署后的 MockPriceFeed 地址
export MOCK_PRICE_FEED="你的MockPriceFeed地址"

# 1.2 在拍卖合约中设置代币的价格聚合器
echo "设置代币价格聚合器..."
cast send $PROXY_ADDRESS \
  "setTokenPriceFeed(address,address)" \
  $TOKEN_ADDRESS \
  $MOCK_PRICE_FEED \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL

# 1.3 查询代币价格
echo "查询代币美元价格..."
cast call $PROXY_ADDRESS \
  "getTokenPriceInUSD(address)(uint256)" \
  $TOKEN_ADDRESS \
  --rpc-url $SEPOLIA_RPC_URL

# 1.4 查询 ETH 价格
echo "查询 ETH 美元价格..."
cast call $PROXY_ADDRESS \
  "getEthPriceInUSD()(uint256)" \
  --rpc-url $SEPOLIA_RPC_URL

# 1.5 测试代币转换为美元
echo "100 个代币 = ? USD"
# 100 * 10^18 = 100000000000000000000
cast call $PROXY_ADDRESS \
  "tokenToUSD(address,uint256)(uint256)" \
  $TOKEN_ADDRESS \
  100000000000000000000 \
  --rpc-url $SEPOLIA_RPC_URL

# ============================================================
# 步骤 2: 创建拍卖
# ============================================================

echo "========== 步骤 2: 创建拍卖 =========="

# 2.1 先铸造一个 NFT（如果还没有）
echo "铸造 NFT..."
cast send $NFT_ADDRESS \
  "safeMint(address)" \
  $MY_ADDRESS \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL

# 2.2 授权拍卖合约转移 NFT
export TOKEN_ID=0  # NFT 的 tokenId
echo "授权拍卖合约..."
cast send $NFT_ADDRESS \
  "approve(address,uint256)" \
  $PROXY_ADDRESS \
  $TOKEN_ID \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL

# 2.3 创建拍卖
# 参数：NFT地址, tokenId, 最低出价(USD,18位小数), 持续时间(秒)
# 最低出价 $100 USD = 100 * 10^18 = 100000000000000000000
# 持续时间 1 小时 = 3600 秒
echo "创建拍卖..."
cast send $PROXY_ADDRESS \
  "createAuction(address,uint256,uint256,uint256)(uint256)" \
  $NFT_ADDRESS \
  $TOKEN_ID \
  100000000000000000000 \
  3600 \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL

# 2.4 查询拍卖信息
export AUCTION_ID=0
echo "查询拍卖信息..."
cast call $PROXY_ADDRESS \
  "auctions(uint256)(address,address,uint256,uint256,uint256,address,uint256,uint8,address,bool)" \
  $AUCTION_ID \
  --rpc-url $SEPOLIA_RPC_URL

# ============================================================
# 步骤 3: 出价
# ============================================================

echo "========== 步骤 3: 出价 =========="

# 3.1 使用 ETH 出价
# 出价 0.05 ETH = 50000000000000000 Wei
echo "使用 ETH 出价 0.05 ETH..."
cast send $PROXY_ADDRESS \
  "bidWithETH(uint256)" \
  $AUCTION_ID \
  --value 50000000000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL

# 3.2 查询当前最高出价（USD）
echo "查询当前最高出价（USD）..."
cast call $PROXY_ADDRESS \
  "getAuctionHighestBidUSD(uint256)(uint256)" \
  $AUCTION_ID \
  --rpc-url $SEPOLIA_RPC_URL

# 3.3 使用 ERC20 代币出价（需要另一个账户，或者出更高价）
# 首先授权拍卖合约使用代币
echo "授权拍卖合约使用代币..."
cast send $TOKEN_ADDRESS \
  "approve(address,uint256)" \
  $PROXY_ADDRESS \
  1000000000000000000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL

# 出价 200 个代币 = 200 * 10^18
echo "使用 200 个代币出价..."
cast send $PROXY_ADDRESS \
  "bidWithERC20(uint256,address,uint256)" \
  $AUCTION_ID \
  $TOKEN_ADDRESS \
  200000000000000000000 \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL

# 3.4 再次查询最高出价
echo "查询更新后的最高出价（USD）..."
cast call $PROXY_ADDRESS \
  "getAuctionHighestBidUSD(uint256)(uint256)" \
  $AUCTION_ID \
  --rpc-url $SEPOLIA_RPC_URL

# ============================================================
# 步骤 4: 结束拍卖
# ============================================================

echo "========== 步骤 4: 结束拍卖 =========="

# 注意：需要等待拍卖时间结束后才能调用
# 可以先查询拍卖结束时间
echo "查询拍卖结束时间..."
cast call $PROXY_ADDRESS \
  "auctions(uint256)(address,address,uint256,uint256,uint256,address,uint256,uint8,address,bool)" \
  $AUCTION_ID \
  --rpc-url $SEPOLIA_RPC_URL

# 结束拍卖（需要在 endTime 之后调用）
echo "结束拍卖..."
cast send $PROXY_ADDRESS \
  "endAuction(uint256)" \
  $AUCTION_ID \
  --private-key $PRIVATE_KEY \
  --rpc-url $SEPOLIA_RPC_URL

echo "========== 完成 =========="

